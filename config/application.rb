require_relative "boot"
require 'rack'
require 'faye'

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RailsWebsocket
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    config.middleware.delete Rack::TempfileReaper
    config.middleware.delete Rack::ETag
    config.middleware.delete Rack::ConditionalGet

    class WebSocketInterceptor
      def incoming(message, callback)
        Rails.logger.info "[WEBSOCKET] Mensagem recebida: #{message.inspect}"
        # Rails.logger.info "[WEBSOCKET] Tipo da mensagem: #{message.class}, Frozen? #{message.frozen?}"

        # Garante que a mensagem seja um objeto mutável
        message = deep_dup(message)

            # Se a mensagem não tem um "channel", precisamos convertê-la corretamente
            unless message.is_a?(Hash) && message.key?("channel")
              Rails.logger.info "[WEBSOCKET] Mensagem não está no formato Bayeux! Convertendo..."

              if message.key?("mensagem")  # Se for uma mensagem de publicação de dados
                message = {
                  "channel" => "/equipamento", # Define o canal correto para comunicação
                  "data" => message # Insere os dados corretamente dentro de "data"
                }
              else # Se não houver "mensagem", assume que é um handshake
                message = {
                  "channel" => "/meta/handshake",
                  "version" => "1.0",
                  "minimumVersion" => "1.0",
                  "supportedConnectionTypes" => ["websocket", "long-polling"]
                }
              end
            end

            Rails.logger.info "[WEBSOCKET] Mensagem final após conversão: #{message.inspect}"

            begin
              callback.call(message)
              # Rails.logger.info "[WEBSOCKET] Callback executado com sucesso!"
            rescue => e
              # Rails.logger.error "[WEBSOCKET] Erro ao chamar callback: #{e.class} - #{e.message}"
              Rails.logger.error e.backtrace.join("\n")
            end
          end

      private

      # Método para fazer uma cópia profunda da mensagem, garantindo que não há objetos congelados
      def deep_dup(obj)
        case obj
        when Hash
          obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
        when Array
          obj.map { |v| deep_dup(v) }
        else
          obj.dup rescue obj # Se não puder duplicar, mantém o original
        end
      end
    end

    config.middleware.use Faye::RackAdapter, mount: "/faye", timeout: 25, extensions: [], engine: { type: Faye::Engine::Memory } do |bayeux|
      # Captura e exibe logs no terminal
      bayeux.add_extension(WebSocketInterceptor.new)

      bayeux.bind(:handshake) do |client_id|
        Rails.logger.info "[FAYE] Handshake recebido de #{client_id}"
      end

      bayeux.bind(:subscribe) do |client_id, channel|
        Rails.logger.info "[FAYE] Cliente #{client_id} inscreveu-se no canal #{channel}"
      end

      bayeux.bind(:unsubscribe) do |client_id, channel|
        Rails.logger.info "[FAYE] Cliente #{client_id} saiu do canal #{channel}"
      end

      bayeux.bind(:disconnect) do |client_id|
        Rails.logger.info "[FAYE] Cliente #{client_id} desconectado"
      end

      # Envolver todo o processo do Faye em um bloco de captura de erros
      begin
        Rails.logger.info "[FAYE] Inicializando Faye..."
      rescue FrozenError => e
        Rails.logger.error "[FAYE] 🚨 ERRO DE ARRAY CONGELADO! 🚨"
        Rails.logger.error "Mensagem que causou erro: #{message.inspect}"
        Rails.logger.error e.backtrace.join("\n")
      rescue => e
        Rails.logger.error "[FAYE] Erro inesperado: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end

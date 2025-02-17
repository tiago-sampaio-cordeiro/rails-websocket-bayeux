require 'faye'
require 'rack'

Faye::WebSocket.load_adapter('thin')


bayeux = Faye::RackAdapter.new(
  mount: '/faye',
  timeout: 25
)

# Interceptar eventos do protocolo Bayeux
bayeux.bind(:handshake) do |client_id|
  puts "🤝 Novo handshake recebido: #{client_id}"
end

bayeux.bind(:subscribe) do |client_id, channel|
  puts "📡 Cliente #{client_id} se inscreveu no canal: #{channel}"
end

bayeux.bind(:publish) do |client_id, channel, data|
  puts "📨 Cliente #{client_id} publicou no canal #{channel}"
  puts "📝 Mensagem recebida: #{data.inspect}"
end

bayeux.bind(:unsubscribe) do |client_id, channel|
  puts "🚫 Cliente #{client_id} cancelou a inscrição do canal: #{channel}"
end

bayeux.bind(:disconnect) do |client_id|
  puts "🔌 Cliente desconectado com client_id: #{client_id}"
end

run bayeux

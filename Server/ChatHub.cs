using System;
using System.Threading.Channels;
using System.Threading.Tasks;
using Microsoft.AspNetCore.SignalR;

namespace TestServer
{
    public class Message
    {
        public string Name { get; set; }
        public string Text { get; set; }
    }
    public class ChatHub : Hub
    {
        public Task Broadcast(Message message)
        {
            return Clients.All.SendAsync("NewMessage", message);
        }

        public string DadJoke()
        {
            return "How do celebrities stay cool? They have many fans";
        }

        public ChannelReader<int> CountDown(int count)
        {
            var channel = Channel.CreateUnbounded<int>();

            Task.Run(async () =>
            {
                for (var i = count; i >= 0; --i)
                {
                    await channel.Writer.WriteAsync(i);
                    await Task.Delay(2000);
                }

                channel.Writer.TryComplete();
            });
            return channel.Reader;
        }
    }
}

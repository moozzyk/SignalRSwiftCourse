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
    }
}

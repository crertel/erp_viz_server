defmodule ErpVizServerWeb.RoomChannel do
  use Phoenix.Channel

  def join("room:lobby", _message, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end
  def join("room:" <> _private_room_name, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_in("new_msg", %{"body"=> body}, socket) do
    broadcast!(socket, "new_msg", %{body: body})
    {:noreply, socket}
  end

  def handle_info(:after_join, socket) do
    ErpVizServer.get_current_state()
    push(socket, "new_msg", %{body: "Welcome aboard!"})
    {:noreply, socket}
  end
end

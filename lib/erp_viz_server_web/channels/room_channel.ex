defmodule ErpVizServerWeb.RoomChannel do
  use Phoenix.Channel
  alias ElixirRigidPhysics, as: ERP

  def join("room:lobby", _message, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end
  def join("room:" <> _private_room_name, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_in("new_msg", %{"body"=> body}, socket) do
    try do
      {ans, bindings} = Code.eval_string(body, [socket: socket ] ++ Map.get(socket.assigns, :bindings, []), __ENV__)
      broadcast!(socket, "new_msg", %{body: inspect(ans)})
    {:noreply, assign(socket, :bindings, bindings)}
  rescue
    error -> IO.inspect( error, label: "Error")
            broadcast!(socket, "server_error_msg", %{body: inspect(error)})
            {:noreply, socket}
  end
  end

  def handle_info(:after_join, socket) do
    {:ok, pid} = ERP.start_link()
    socket = assign(socket, :erps, pid)
    :ok = ERP.subscribe_to_world_updates(pid)

    push(socket, "new_msg", %{body: "Welcome aboard!"})
    {:noreply, socket}
  end

  def handle_info({:world_update, world}, socket) do
    push(socket, "sim_msg", %{body: Jason.encode!(world)} )
    {:noreply, socket}
  end
end

defimpl Jason.Encoder, for: ElixirRigidPhysics.World do
  def encode(%ElixirRigidPhysics.World{bodies: bodies} = world, opts) do

    clean_bodies = for {ref, body} <- bodies, into: %{} do

      clean_body = for {k, v} <- body, into: %{} do
        case {k,v} do
          {:transform, {m11,m12,m13,m14,
               m21,m22,m23,m24,
               m31,m32,m33,m34,
               m41,m42,m43,m44} = _mat4x4} -> {k, [m11,m12,m13,m14,
               m21,m22,m23,m24,
               m31,m32,m33,m34,
               m41,m42,m43,m44]}
          {k, v} -> {k, v}
        end
      end

      {inspect(ref), clean_body}
    end

    Jason.Encode.map( %ElixirRigidPhysics.World{ world | bodies: clean_bodies}, opts)

    #Jason.Encode.map(Map.take(value, [:timestep, bodies), opts)
  end
end

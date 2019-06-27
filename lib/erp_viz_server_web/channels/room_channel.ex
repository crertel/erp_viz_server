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
    broadcast!(socket, "new_msg", %{body: body})
    {:noreply, socket}
  end

  def handle_in("server_eval", %{"body"=> body}, socket) do
    try do
      {ans, bindings} = Code.eval_string(body, [socket: socket ] ++ Map.get(socket.assigns, :bindings, []), __ENV__)
      push(socket, "server_eval_result", %{body: inspect(ans)} )
      {:noreply, assign(socket, :bindings, bindings)}
    rescue
      error -> IO.inspect( error, label: "Error")
              push(socket, "server_error_msg", %{body: inspect(error)} )
              {:noreply, socket}
    end
  end

  def handle_info(:after_join, socket) do
    #{:ok, pid} = ERP.start_link()

    socket = assign(socket, :erps, ERPS)
    ERP.subscribe_to_world_updates(ERPS)

    push(socket, "new_msg", %{body: "Welcome aboard!"})
    {:noreply, socket}
  end

  def handle_info({:world_update, world}, socket) do
    push(socket, "sim_msg", %{body: Jason.encode!(world)} )
    {:noreply, socket}
  end

  def handle_info(msg, state) do
    IO.inspect(msg, label: "no idea what this is")
    {:noreply, state}
  end

  def ref_string_to_ref(str) do
    str
    |> String.replace_leading("#Reference", "#Ref")
    |> String.to_charlist()
    |> :erlang.list_to_ref()
  end
end

defimpl Jason.Encoder, for: ElixirRigidPhysics.World do
  defp sanitize_terms(term) when is_map(term) do
    for {k, v} <- term, into: %{} do
      case {k,v} do
        {k, v} -> {k, sanitize_terms(v)}
      end
    end
  end
  defp sanitize_terms(term) when is_reference(term), do: "#{inspect term}"
  defp sanitize_terms(term) when is_tuple(term), do:  Tuple.to_list(term)
  defp sanitize_terms(term), do: term

  def encode(%ElixirRigidPhysics.World{bodies: bodies} = world, opts) do
    alias ElixirRigidPhysics.Dynamics.Body

    clean_bodies = for {ref, raw_body} <- bodies, into: %{} do
      body_map = Body.to_map(raw_body)
      clean_body = sanitize_terms(body_map)
      {inspect(ref), clean_body}
    end

    Jason.Encode.map( %ElixirRigidPhysics.World{ world | bodies: clean_bodies}, opts)
  end
end

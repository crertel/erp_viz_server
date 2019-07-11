defmodule ErpVizServerWeb.RoomChannel do
  use Phoenix.Channel
  alias ElixirRigidPhysics, as: ERP

  alias Graphmath.Quatern
  alias Graphmath.Vec3

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
      {ans, bindings} = Code.eval_string(body, [socket: socket, start: &start/0, stop: &stop/0, clear: &clear/0, get_commands: &get_commands/0, setup_scene: &setup_scene/1 ] ++ Map.get(socket.assigns, :bindings, []), __ENV__)
      push(socket, "server_eval_result", %{body: inspect(ans)} )
      {:noreply, assign(socket, :bindings, bindings)}
    rescue
      error -> IO.inspect( error, label: "Error")
              push(socket, "server_error_msg", %{body: inspect(error)} )
              {:noreply, socket}
    end
  end

  def start(), do: ERP.start_world_simulation(ERPS)
  def stop(), do: ERP.stop_world_simulation(ERPS)
  def clear(), do: ERP.remove_all_bodies_from_world(ERPS)

  def setup_scene(:spiral) do
    ERP.remove_all_bodies_from_world(ERPS);
    sphere = ERP.Geometry.Sphere.create(1)
    num_spheres = 16
    for i <- 0..num_spheres do
      b = ERP.Dynamics.Body.create(sphere, position: {
        i * :math.sin( (1.0 * i/num_spheres)*(2 * :math.pi())),
        0.15 * i,
        i * :math.cos( (1.0 * i/num_spheres)*(2 * :math.pi())),
      })
      ERP.add_body_to_world(ERPS, b)
    end
  end

  def setup_scene(:capsules) do
    ERP.remove_all_bodies_from_world(ERPS);
    capsule1 = ERP.Geometry.Capsule.create(4,0.25)
    b1 = ERP.Dynamics.Body.create(capsule1, position: { 0.2, 0.75, 0.0 }, orientation: {1.0, 0.0, 0.0, 0.0})
    ERP.add_body_to_world(ERPS, b1)

    capsule2 = ERP.Geometry.Capsule.create(4,0.25)
    sqrthalf = :math.sqrt(0.5)
    b2 = ERP.Dynamics.Body.create(capsule2, position: { 0.0, 0.0, 0.75 }, orientation: {sqrthalf, sqrthalf, 0.0, 0.0})
    ERP.add_body_to_world(ERPS, b2)

    capsule3 = ERP.Geometry.Capsule.create(4,0.25)
    sqrthalf = :math.sqrt(0.5)
    b3 = ERP.Dynamics.Body.create(capsule3, position: { 0.4, 2.0, -0.75 }, orientation: {sqrthalf, sqrthalf, 0.0, 0.0})
    ERP.add_body_to_world(ERPS, b3)
  end

  def setup_scene(:capsule_and_sphere) do
    ERP.remove_all_bodies_from_world(ERPS);
    sphere = ERP.Geometry.Sphere.create(1)
    b = ERP.Dynamics.Body.create(sphere, position: { 0.5, 0.0, 0.75 })
    ERP.add_body_to_world(ERPS, b)
    capsule = ERP.Geometry.Capsule.create(4,0.25)
    sqrthalf = :math.sqrt(0.5)
    b2 = ERP.Dynamics.Body.create(capsule, position: { 0.0, 0.75, 0.0 }, orientation: {sqrthalf, sqrthalf, 0.0, 0.0})
    ERP.add_body_to_world(ERPS, b2)
  end

  def setup_scene(:two_spheres) do
    ERP.remove_all_bodies_from_world(ERPS);
    sphere = ERP.Geometry.Sphere.create(1)
    b = ERP.Dynamics.Body.create(sphere, position: { 0.0, 0.0, 0.0 })
    ERP.add_body_to_world(ERPS, b)
    b2 = ERP.Dynamics.Body.create(sphere, position: { 0.0, 0.75, 0.0 })
    ERP.add_body_to_world(ERPS, b2)
  end

  def setup_scene(:bedlam_small) do
    bodies = for _x <- 1..100, into: [] do
      shape = case :random.uniform(3) do
        1 -> ERP.Geometry.Sphere.create( 5 * :random.uniform())
        2 -> ERP.Geometry.Capsule.create( 5 * :random.uniform(), 2 * :random.uniform())
        3 -> ERP.Geometry.Box.create( 5 * :random.uniform(), 5 * :random.uniform(), 5 * :random.uniform())
      end

      ERP.Dynamics.Body.create( shape,
                                        position: Vec3.random_ball() |> Vec3.scale(60),
                                        orientation: Quatern.random(),
                                        angular_velocity: Vec3.random_sphere() |> Vec3.scale( :random.uniform() * 5),
                                        linear_velocity: Vec3.random_sphere() |> Vec3.scale( :random.uniform() * 5)
                                        )
    end

    ERP.add_bodies_to_world(ERPS, bodies)
  end

  def setup_scene(:bedlam_large) do
    bodies = for _x <- 1..100, into: [] do
      shape = case :random.uniform(3) do
        1 -> ERP.Geometry.Sphere.create( 5 * :random.uniform())
        2 -> ERP.Geometry.Capsule.create( 5 * :random.uniform(), 2 * :random.uniform())
        3 -> ERP.Geometry.Box.create( 5 * :random.uniform(), 5 * :random.uniform(), 5 * :random.uniform())
      end

      ERP.Dynamics.Body.create( shape,
                                        position: Vec3.random_ball() |> Vec3.scale(60),
                                        orientation: Quatern.random(),
                                        angular_velocity: Vec3.random_sphere() |> Vec3.scale( :random.uniform() * 5),
                                        linear_velocity: Vec3.random_sphere() |> Vec3.scale( :random.uniform() * 5)
                                        )
    end

    ERP.add_bodies_to_world(ERPS, bodies)
  end

  def get_commands() do
    """
    ERP functions:
    #{inspect  ERP.__info__(:functions)}

    ERP.Geometry.Sphere:
    #{inspect  ERP.Geometry.Sphere.__info__(:functions)}

    ERP.Geometry.Capsule:
    #{ inspect ERP.Geometry.Capsule.__info__(:functions)}

    ERP.Geometry.Box:
    #{inspect ERP.Geometry.Box.__info__(:functions)}

    ERP.Dynamics.Body:
    #{inspect ERP.Dynamics.Body.__info__(:functions)}

    """
  end

  def handle_info(:after_join, socket) do
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
  defp sanitize_terms(term) when is_tuple(term), do:  Tuple.to_list(term) |> Enum.map( &sanitize_terms/1)
  defp sanitize_terms(term) when is_list(term), do: Enum.map( term, &sanitize_terms/1)
  defp sanitize_terms(term), do: term

  def encode(%ElixirRigidPhysics.World{bodies: bodies, collisions: collisions} = world, opts) do
    alias ElixirRigidPhysics.Dynamics.Body

    clean_bodies = for {ref, raw_body} <- bodies, into: %{} do
      body_map = Body.to_map(raw_body)
      clean_body = sanitize_terms(body_map)
      {inspect(ref), clean_body}
    end

    clean_world = Map.delete(world, :broadphase_acceleration_structure)
    Jason.Encode.map( %ElixirRigidPhysics.World{ clean_world | bodies: clean_bodies, collisions: sanitize_terms(collisions)}, opts)
  end
end

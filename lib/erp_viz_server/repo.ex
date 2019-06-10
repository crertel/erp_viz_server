defmodule ErpVizServer.Repo do
  use Ecto.Repo,
    otp_app: :erp_viz_server,
    adapter: Ecto.Adapters.Postgres
end

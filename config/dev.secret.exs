use Mix.Config

config :erp_viz_server, ErpVizServer.Repo,
  username: "erp_viz",
  password: "erperperp",
  database: "erp_viz_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

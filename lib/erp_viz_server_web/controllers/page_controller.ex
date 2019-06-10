defmodule ErpVizServerWeb.PageController do
  use ErpVizServerWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end

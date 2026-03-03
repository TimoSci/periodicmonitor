defmodule PeriodicmonitorWeb.PageController do
  use PeriodicmonitorWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

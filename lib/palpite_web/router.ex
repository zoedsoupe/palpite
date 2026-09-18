defmodule PalpiteWeb.Router do
  use PalpiteWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PalpiteWeb.Layouts, :root}
    plug :put_layout, html: {PalpiteWeb.Layouts, :app}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug PalpiteWeb.Plugs.Identity
  end

  scope "/", PalpiteWeb do
    pipe_through :browser

    live_session :app,
      layout: {PalpiteWeb.Layouts, :app},
      on_mount: [{PalpiteWeb.Hooks.Identity, :default}],
      session: {PalpiteWeb.Plugs.Identity, :live_session, []} do
      live "/", HomeLive
      live "/descobrir", DiscoverLive
      live "/meus-titulos", MyTitlesLive
    end

    get "/honestidade", HonestyController, :show
    get "/recuperar", RecoveryController, :new
    post "/recuperar", RecoveryController, :create
  end
end

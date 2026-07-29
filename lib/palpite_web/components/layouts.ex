defmodule PalpiteWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use PalpiteWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Shows an element matching the given selector, via `Phoenix.LiveView.JS.show/2`.

  Accepts either a selector string or a `%Phoenix.LiveView.JS{}` struct
  piped in plus a selector string.

  ## Examples

      show("#sheet")
      JS.push("open") |> show("#sheet")

  """
  def show(selector) when is_binary(selector), do: JS.show(to: selector)
  def show(%JS{} = js, selector) when is_binary(selector), do: JS.show(js, to: selector)

  @doc """
  Hides an element matching the given selector, via `Phoenix.LiveView.JS.hide/2`.

  Accepts either a selector string or a `%Phoenix.LiveView.JS{}` struct
  piped in plus a selector string.

  ## Examples

      hide("#sheet")
      JS.push("close") |> hide("#sheet")

  """
  def hide(selector) when is_binary(selector), do: JS.hide(to: selector)
  def hide(%JS{} = js, selector) when is_binary(selector), do: JS.hide(js, to: selector)

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="site-header">
      <div class="container cluster">
        <.link navigate={~p"/"} class="wordmark">
          <Lucideicons.popcorn class="icon" /> palpite
        </.link>
        <nav class="site-nav" aria-label={gettext("main navigation")}>
          <.link navigate={~p"/"} class="nav-link">{gettext("discover")}</.link>
          <.link navigate="/my-titles" class="nav-link">{gettext("my titles")}</.link>
          <.link navigate="/honesty" class="nav-link">{gettext("honesty")}</.link>
        </nav>
      </div>
    </header>

    <main class="page container">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash
        id="welcome-back"
        kind={:info}
        phx-mounted={show("#welcome-back") |> JS.remove_attribute("hidden")}
        hidden
      >
        Welcome Back!
      </.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast-region"
      {@rest}
    >
      <div class={["toast", "toast-#{@kind}"]}>
        <Lucideicons.info :if={@kind == :info} class="icon" />
        <Lucideicons.circle_alert :if={@kind == :error} class="icon" />
        <div class="toast-body">
          <p :if={@title} class="toast-title">{@title}</p>
          <p>{msg}</p>
        </div>
        <button type="button" class="toast-close" aria-label={gettext("close")}>
          <Lucideicons.x class="icon" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <Lucideicons.loader_circle class="icon spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <Lucideicons.loader_circle class="icon spin" />
      </.flash>
    </div>
    """
  end
end

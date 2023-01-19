defmodule Phoenix.LiveDashboard.Components.AcNavBarComponent do
  use Phoenix.LiveDashboard.Web, :live_component

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, normalize_assigns(assigns))}
  end

  def normalize_assigns(assigns) do
    case Map.fetch(assigns, :item) do
      :error ->
        raise ArgumentError, "the :items parameter is expected in nav bar component"

      {:ok, no_list} when not is_list(no_list) ->
        msg = ":items parameter must be a list, got: "
        raise ArgumentError, msg <> inspect(no_list)

      {:ok, items} ->
        nav_param = normalize_nav_param(assigns)
        current = normalize_current(assigns.page.params, items, nav_param)

        %{
          page: assigns.page,
          current: current,
          items: items,
          nav_param: nav_param,
          extra_params: normalize_extra_params(assigns, nav_param),
          style: normalize_style(assigns)
        }
    end
  end

  defp normalize_current(url_params, items, nav_param) do
    with %{^nav_param => item_name} <- url_params,
         current when not is_nil(current) <- Enum.find(items, &(&1.name == item_name)) do
      current
    else
      _ -> default_current(items)
    end
  end

  defp default_current([first | _]), do: first

  defp normalize_extra_params(assigns, nav_param) do
    case Map.fetch(assigns, :extra_params) do
      :error ->
        []

      {:ok, extra_params_list} when is_list(extra_params_list) ->
        unless Enum.all?(extra_params_list, &(is_binary(&1) or is_atom(&1))) do
          msg = ":extra_params must be a list of strings or atoms, got: "
          raise ArgumentError, msg <> inspect(extra_params_list)
        end

        extra_params_list = Enum.map(extra_params_list, &to_string/1)

        if nav_param in extra_params_list do
          msg = ":extra_params must not contain the :nav_param field name #{inspect(nav_param)}"

          raise ArgumentError, msg
        end

        extra_params_list

      {:ok, extra_params} ->
        msg = ":extra_params must be a list of strings or atoms, got: "
        raise ArgumentError, msg <> inspect(extra_params)
    end
  end

  defp normalize_nav_param(assigns) do
    case Map.fetch(assigns, :nav_param) do
      :error ->
        "nav"

      {:ok, nav_param} when is_binary(nav_param) ->
        nav_param

      {:ok, nav_param} when is_atom(nav_param) ->
        Atom.to_string(nav_param)

      {:ok, nav_param} ->
        raise ArgumentError,
              ":nav_param parameter must be an string or atom, got: #{inspect(nav_param)}"
    end
  end

  defp normalize_style(assigns) do
    style = Map.get(assigns, :style, :pills)

    unless style in [:pills, :bar] do
      raise ArgumentError, ":style must be either :pills or :bar"
    end

    style
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="row">
        <div class="container">
          <ul class={"nav nav-#{@style} mt-n2 mb-4"}>
            <li :for={item <- @items} class="nav-item">
              <.link {item_link_href(@socket, @page, item, @nav_param, @extra_params)} class={item_link_class(item, @current)}>
                <%= item.name %>
              </.link>
            </li>
          </ul>
        </div>
      </div>
      <%= render_slot(@current) %>
    </div>
    """
  end

  defp item_link_href(socket, page, item, nav_param, extra_params) do
    params_to_keep = for {key, value} <- page.params, key in extra_params, do: {key, value}

    path =
      Phoenix.LiveDashboard.PageBuilder.live_dashboard_path(
        socket,
        page.route,
        page.node,
        page.params,
        [{nav_param, item.name} | params_to_keep]
      )

    case Map.fetch(item, :method) do
      :error -> [patch: path]
      {:ok, "patch"} -> [patch: path]
      {:ok, "navigate"} -> [navigate: path]
      {:ok, "href"} -> [href: path]
      {:ok, "redirect"} -> [href: path]
    end
  end

  defp item_link_class(current, current), do: "nav-link active"
  defp item_link_class(_, _), do: "nav-link"
end

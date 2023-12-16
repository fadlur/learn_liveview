defmodule LearnLiveviewWeb.ThermostatLive do
  alias LearnLiveview.Thermostat
  use Phoenix.LiveView

  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    Current temperature: <%= @temperature %>°F
    <br />
    <button phx-click="inc_temperature">+</button>
    <button phx-click="dec_temperature">-</button>
    """
  end

  def mount(%{"house" => house}, _session, socket) do
    temperature = Thermostat.get_house_reading(house) # Let's assume a fixed temperatur for now
    {:ok, assign(socket, :temperature, temperature)}
  end

  def handle_event("inc_temperature", _params, socket) do
    {:noreply, update(socket, :temperature, &(&1 + 1))}
  end

  def handle_event("dec_temperature", _params, socket) do
    {:noreply, update(socket, :temperature, &(&1 - 1))}
  end

end

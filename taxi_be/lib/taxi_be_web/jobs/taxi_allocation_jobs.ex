defmodule TaxiBeWeb.TaxiAllocationJob do
  use GenServer

  def start_link(request, name) do
    GenServer.start_link(__MODULE__, request, name: name)
  end

  def init(request) do
    Process.send(self(), :step1, [:nosuspend])
    {:ok, %{request: request, status: :not_accepted, contacted_taxi: nil}}
  end

  def handle_info(:step1, %{request: request} = state) do
    # Select a taxi
    # taxi = Enum.take_random(candidate_taxis(), 1) |> hd()

    task = Task.async(fn -> compute_ride_fare(request) |> notify_customer_ride_fare() end)
    # taxi = Enum.take_random(select_candidate_taxis(request), 1) |> hd()
    taxis = select_candidate_taxis(request)
    Task.await(task)
    Process.send(self(), :block1, [:nosuspend])
    # task = Task.async(fn -> Enum.take_random(select_candidate_taxis(request), 1) |> hd() end)
    # compute_ride_fare((request)) |> notify_customer_ride_fare()

    # Forward request to taxi driver
    # %{
    #   "pickup_address" => pickup_address,
    #   "dropoff_address" => dropoff_address,
    #   "booking_id" => booking_id
    # } = request
    # TaxiBeWeb.Endpoint.broadcast(
    #   "driver:" <> taxi.nickname,
    #   "booking_request",
    #    %{
    #      msg: "Viaje de '#{pickup_address}' a '#{dropoff_address}'",
    #      bookingId: booking_id
    #     })

    {:noreply, state |> Map.put(:candidates, taxis)}
  end

  def handle_info(:block1, %{request: request, candidates: taxis} = state) do
    if taxis != [] do
      taxi = hd(taxis)
      # Forward request to taxi driver
      %{
        "pickup_address" => pickup_address,
        "dropoff_address" => dropoff_address,
        "booking_id" => booking_id
      } = request
      TaxiBeWeb.Endpoint.broadcast(
        "driver:" <> taxi.nickname,
        "booking_request",
        %{
          msg: "Viaje de '#{pickup_address}' a '#{dropoff_address}'",
          bookingId: booking_id
          })

    Process.send_after(self(), :timeout1, 20000)
    Map.put(state, :contacted_taxi, taxi)
    {:noreply, %{state | contacted_taxi: taxi, request: request, candidates: tl(taxis)}}
  else
    {:noreply, state}
  end
  end

  def handle_info(:timeout1, state) do
    Process.send(self(), :block1, [:nosuspend])
    {:noreply, state}
  end

  def handle_cast({:process_accept, driver_name}, %{request: request, status: :not_accepted, contacted_taxi: taxi} = state) do
    IO.inspect(request)
    IO.inspect(state.status)
    %{"username" => username} = request
    # TaxiBeWeb.Endpoint.broadcast("customer: " <> username, "booking_request", %{msg: "Tu taxi esta en camino"})
    task = Task.async(fn -> notify_customer_ride_driverinfo(taxi, request) end)
    Task.await(task)
    new_state = Map.put(state, :status, :accepted)
    IO.inspect(new_state.status)
    {:noreply, new_state}
  end

  def handle_cast({:process_accept, driver_name}, %{request: request, status: :accepted} = state) do
    IO.inspect(state.request)
    IO.inspect(state.status)
    %{"username" => username} = request
    TaxiBeWeb.Endpoint.broadcast("driver:" <> driver_name, "booking_request", %{msg: "Viaje aceptado por alguien más"})
    {:noreply, state}
  end

  def handle_cast({:process_reject, driver_name}, state) do
    Process.send(self(), :block1, [:nosuspend])
    {:noreply, state}
  end

  def compute_ride_fare(request) do
    %{
      "pickup_address" => pickup_address,
      "dropoff_address" => dropoff_address
     } = request

    coord1 = TaxiBeWeb.Geolocator.geocode(pickup_address)
    coord2 = TaxiBeWeb.Geolocator.geocode(dropoff_address)
    # IO.puts(coord1)
    {distance, duration} = TaxiBeWeb.Geolocator.distance_and_duration(coord1, coord2)
    {request, distance, Float.ceil(duration/60)}
  end

  def notify_customer_ride_fare({request, fare, _duration}) do
    %{"username" => customer} = request
   TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request", %{msg: "Ride fare: #{Float.ceil(fare/80)}"})
  end

  def notify_customer_ride_driverinfo(driver, request) do
    %{
      "pickup_address" => pickup_address,
      "dropoff_address" => dropoff_address
     } = request

    coord1 = TaxiBeWeb.Geolocator.geocode(pickup_address)
    %{"username" => customer} = request
    taxicoords = {:ok, [driver.longitude, driver.latitude]}
    {distance, duration} = TaxiBeWeb.Geolocator.distance_and_duration(taxicoords, coord1)
   TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request", %{msg: "Driver #{driver.nickname} is: #{distance} meters away from you, will arrive in #{Float.ceil(duration/60)} minutes"})
  end

  def select_candidate_taxis(%{"pickup_address" => _pickup_address}) do
    [
      %{nickname: "jejejeje", latitude: 19.0319783, longitude: -98.2349368}, # Angelopolis
      %{nickname: "alonse", latitude: 19.0061167, longitude: -98.2697737}, # Arcangeles
      %{nickname: "alekong", latitude: 19.0092933, longitude: -98.2473716} # Paseo Destino
    ]
  end

end

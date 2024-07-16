defmodule UserWorker do
  use GenServer
  require Logger

  def start_link(user, serverPid) do
    Logger.debug("start_link user #{user}")
    GenServer.start_link(__MODULE__, [user, serverPid], name: {:global, user})
  end

  def init([userId, serverPid]) do
    state = %{:id => userId, :server => serverPid}
    {:ok, state}
  end

  def handle_call({:deposit, amount, currency}, _from, state) do
    Logger.debug("#{state[:id]} deposit #{amount}(#{currency})")
    {newState, reply} = update_wallet(:deposit, {state, currency, amount})
    {:reply, reply, newState}
  end

  def handle_cast({:deposit, amount, currency}, state) do
    Logger.debug("#{state[:id]} deposit #{amount}(#{currency})")
    {newState, reply} = update_wallet(:deposit, {state, currency, amount})
    do_replay(newState[:server], reply)
    {:noreply, newState}
  end

  def handle_cast({:withdraw, amount, currency}, state) do
    Logger.debug("#{state[:id]} withdraw #{amount}(#{currency})")
    {newState, reply} = update_wallet(:withdraw, {state, currency, amount})
    do_replay(newState[:server], reply)
    {:noreply, newState}
  end

  def handle_cast({:get_balance, currency}, state) do
    Logger.debug("#{state[:id]} get_balance (#{currency})")
    reply = {:ok, Map.get(state, currency, 0)}
    do_replay(state[:server], reply)
    {:noreply, state}
  end

  def handle_cast({:send, receiver_pid, amount, currency}, state) do
    Logger.debug("#{state[:id]} send #{amount}(#{currency})")

    {newState, reply} =
      case update_wallet(:withdraw, {state, currency, amount}) do
        {newState, {:ok, from_user_balance}} ->
          case GenServer.call(receiver_pid, {:deposit, amount, currency}) do
            {:ok, to_user_balance} ->
              {newState, {:ok, from_user_balance, to_user_balance}}

            _ ->
              {state, {:error, :receiver_error}}
          end

        {newState, reply} ->
          {newState, reply}
      end

    do_replay(newState[:server], reply)
    {:noreply, newState}
  end

  def handle_info(:timeout, state) do
    Logger.debug("#{state[:id]} :timeout")
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.debug("#{state[:id]} #{inspect(reason)}")
    :ok
  end

  # ------Helpers-------

  defp do_replay(pid, msg) do
    GenServer.cast(pid, msg)
  end

  defp update_wallet(:withdraw, {state, currency, amount}) do
    curAmount = Map.get(state, currency, 0)

    case curAmount < amount do
      true ->
        {state, {:error, :not_enough_money}}

      false ->
        newAmount = format_money(curAmount - amount)
        newState = Map.put(state, currency, newAmount)
        {newState, {:ok, newAmount}}
    end
  end

  defp update_wallet(:deposit, {state, currency, amount}) do
    curAmount = Map.get(state, currency, 0)
    newAmount = format_money(curAmount + amount)
    newState = Map.put(state, currency, newAmount)
    {newState, {:ok, newAmount}}
  end

  defp format_money(amount) when is_float(amount) do
    :erlang.float_to_binary(amount, decimals: 2)
    |> :erlang.binary_to_float()
  end

  defp format_money(amount) when is_integer(amount) do
    Float.round(amount / 1, 2)
  end
end

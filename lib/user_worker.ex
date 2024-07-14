defmodule UserWorker do
  use GenServer
  require Logger

  def start_link(user) do
    Logger.debug("start_link user #{user}")
    GenServer.start_link(__MODULE__, [user], name: {:global, user})
  end

  def init([userId]) do
    state = %{:id => userId}
    {:ok, state}
  end

  def handle_call({:deposit, amount, currency}, _from, state) do
    :timer.sleep(4000)
    Logger.debug("#{state[:id]} deposit #{amount}(#{currency})")
    update_wallet(:deposit, {state, currency, amount})
  end

  def handle_call({:withdraw, amount, currency}, _from, state) do
    Logger.debug("#{state[:id]} withdraw #{amount}(#{currency})")
    update_wallet(:withdraw, {state, currency, amount})
  end

  def handle_call({:get_balance, currency}, _from, state) do
    Logger.debug("#{state[:id]} get_balance (#{currency})")
    :timer.sleep(4000)
    {:reply, {:ok, Map.get(state, currency, 0)}, state}
  end

  def handle_call({:send, receiver_pid, amount, currency}, _from, state) do
    Logger.debug("#{state[:id]} send #{amount}(#{currency})")

    case update_wallet(:withdraw, {state, currency, amount}) do
      {_, {:ok, from_user_balance}, new_state} ->
        case GenServer.call(receiver_pid, {:deposit, amount, currency}) do
          {:ok, to_user_balance} ->
            {:reply, {:ok, from_user_balance, to_user_balance}, new_state}

          {:error, _} = reply ->
            {:reply, {:error, :receiver_error}, state}
        end

      reply ->
        reply
    end
  end

  def handle_info(:timeout, state) do
    Logger.debug("#{state[:id]} :timeout")
    {:noreply, state}
  end

  def terminate(reason, state) do
    Logger.debug("#{state[:id]} #{reason}")
    :ok
  end

  # ------Helpers-------

  def update_wallet(:withdraw, {state, currency, amount}) do
    case Map.get(state, currency, 0) < amount do
      true ->
        {:reply, {:error, :not_enough_money}, state}

      false ->
        new_state = Map.update(state, currency, amount, &(&1 - amount))
        {:reply, {:ok, new_state[currency]}, new_state}
    end
  end

  def update_wallet(:deposit, {state, currency, amount}) do
    new_state = Map.update(state, currency, amount, &(&1 + amount))
    {:reply, {:ok, new_state[currency]}, new_state}
  end
end

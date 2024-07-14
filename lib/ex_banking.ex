defmodule ExBanking do
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_cast(message, state) do
    Logger.info("#{inspect(message)}")
    {:noreply, state}
  end

  # ------API------
  @spec create_user(user :: String.t()) :: :ok | {:error, :wrong_arguments | :user_already_exists}
  def create_user(user) when is_binary(user) do
    Task.start(fn -> do_create_user(user) end)
    :ok
  end

  def create_user(user) do
    {:error, :wrong_arguments}
  end

  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def deposit(user, amount, currency)
      when is_binary(user) and is_number(amount) and is_binary(currency) do
    Task.start(fn -> do_deposit(user, amount, currency) end)
    :ok
  end

  def deposit(user, amount, currency) do
    {:error, :wrong_arguments}
  end

  @spec withdraw(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error,
             :wrong_arguments
             | :user_does_not_exist
             | :not_enough_money
             | :too_many_requests_to_user}
  def withdraw(user, amount, currency)
      when is_binary(user) and is_number(amount) and is_binary(currency) do
    Task.start(fn -> do_withdraw(user, amount, currency) end)
    :ok
  end

  def withdraw(user, amount, currency) do
    {:error, :wrong_arguments}
  end

  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def get_balance(user, currency) when is_binary(user) and is_binary(currency) do
    Task.start(fn -> do_get_balance(user, currency) end)
    :ok
  end

  def get_balance(user, currency) do
    {:error, :wrong_arguments}
  end

  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number,
          currency :: String.t()
        ) ::
          {:ok, from_user_balance :: number, to_user_balance :: number}
          | {:error,
             :wrong_arguments
             | :not_enough_money
             | :sender_does_not_exist
             | :receiver_does_not_exist
             | :too_many_requests_to_sender
             | :too_many_requests_to_receiver}
  def send(from_user, to_user, amount, currency)
      when is_binary(from_user) and is_binary(to_user) and is_number(amount) and
             is_binary(currency) do
    Task.start(fn -> do_send(from_user, to_user, amount, currency) end)
    :ok
  end

  def send(from_user, to_user, amount, currency) do
    {:error, :wrong_arguments}
  end

  # ------------------

  defp do_create_user(user) do
    response =
      case :global.whereis_name(user) do
        :undefined ->
          Sup.init_user(user)
          :ok

        _ ->
          {:error, :user_already_exists}
      end

    display(response)
  end

  defp do_deposit(user, amount, currency) do
    response =
      case find_user_and_check_queue(user) do
        {:ok, pid} -> GenServer.call(pid, {:deposit, amount, currency})
        error -> error
      end

    display(response)
  end

  defp do_withdraw(user, amount, currency) do
    response =
      case find_user_and_check_queue(user) do
        {:ok, pid} -> GenServer.call(pid, {:withdraw, amount, currency})
        error -> error
      end

    display(response)
  end

  defp do_get_balance(user, currency) do
    response =
      case find_user_and_check_queue(user) do
        {:ok, pid} -> GenServer.call(pid, {:get_balance, currency})
        error -> error
      end

    display(response)
  end

  defp do_send(from_user, to_user, amount, currency) do
    response =
      case {find_user_and_check_queue(from_user), find_user_and_check_queue(to_user)} do
        {{:ok, from_pid}, {:ok, to_pid}} ->
          GenServer.call(from_pid, {:send, to_pid, amount, currency})

        {{:error, :user_does_not_exist}, _} ->
          {:error, :sender_does_not_exist}

        {{:error, :too_many_requests_to_user}, _} ->
          {:error, :too_many_requests_to_sender}

        {_, {:error, :user_does_not_exist}} ->
          {:error, :receiver_does_not_exist}

        {_, {:error, :too_many_requests_to_user}} ->
          {:error, :too_many_requests_to_receiver}
      end

    display(response)
  end

  # ------helpers------
  defp display(msg) do
    GenServer.cast(__MODULE__, msg)
  end

  defp find_user_and_check_queue(user) do
    case :global.whereis_name(user) do
      :undefined ->
        {:error, :user_does_not_exist}

      pid ->
        case Process.info(pid, :message_queue_len) do
          {:message_queue_len, len} when len < 10 ->
            {:ok, pid}

          len ->
            {:error, :too_many_requests_to_user}
        end
    end
  end
end

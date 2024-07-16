defmodule ExBankingTest do
  use ExUnit.Case

  setup do
    {:ok, _} = Application.ensure_all_started(:ex_banking)

    on_exit(fn ->
      Application.stop(:ex_banking)
    end)

    :ok
  end

  describe "create_user/1" do
    @tag :reqular
    test "creates a new user successfully" do
      ExBanking.create_user("alice")
      reply = ExBanking.create_user("alice")
      assert reply == {:error, :user_already_exists}
    end

    @tag :reqular
    test "returns error with invalid arguments" do
      assert ExBanking.create_user(123) == {:error, :wrong_arguments}
    end

    @tag :reqular
    test "returns error with invalid arguments - empty user" do
      assert ExBanking.create_user("") == {:error, :wrong_arguments}
    end
  end

  describe "deposit/3" do
    setup do
      {:ok, pid} = Sup.init_user({"bob", self()})

      on_exit(fn ->
        Process.exit(pid, :stop)
      end)

      :ok
    end

    @tag :reqular
    test "deposits money successfully" do
      ExBanking.deposit("bob", 101, "USD")
      assert_receive {:"$gen_cast", {:ok, 101.0}}, 1_000
    end

    @tag :reqular
    test "returns error if user does not exist" do
      assert ExBanking.deposit("charlie", 100, "USD") == {:error, :user_does_not_exist}
    end

    @tag :reqular
    test "returns error with invalid arguments" do
      assert ExBanking.deposit("bob", -50, "USD") == {:error, :wrong_arguments}
      assert ExBanking.deposit("bob", 100, 123) == {:error, :wrong_arguments}
    end

    @tag :perf
    test "returns error if there are too many requests to user" do
      for _ <- 1..100 do
        ExBanking.deposit("bob", 100, "USD")
      end

      assert ExBanking.deposit("bob", 100, "USD") == {:error, :too_many_requests_to_user}
    end
  end

  describe "withdraw/3" do
    setup do
      {:ok, pid} = Sup.init_user({"dave", self()})
      ExBanking.deposit("dave", 100, "USD")
      assert_receive {:"$gen_cast", {:ok, 100.0}}, 1_000

      on_exit(fn ->
        Process.exit(pid, :stop)
      end)

      :ok
    end

    @tag :reqular
    test "withdraws money successfully" do
      ExBanking.withdraw("dave", 50, "USD")
      assert_receive {:"$gen_cast", {:ok, 50.0}}, 1_000
    end

    @tag :reqular
    test "returns error if not enough money" do
      ExBanking.withdraw("dave", 100.01, "USD")
      assert_receive {:"$gen_cast", {:error, :not_enough_money}}, 1_000
    end

    @tag :reqular
    test "returns error if user does not exist" do
      assert ExBanking.withdraw("eve", 50, "USD") == {:error, :user_does_not_exist}
    end

    @tag :reqular
    test "returns error with invalid arguments" do
      assert ExBanking.withdraw("dave", -50, "USD") == {:error, :wrong_arguments}
      assert ExBanking.withdraw("dave", 50, 123) == {:error, :wrong_arguments}
    end
  end

  describe "get_balance/2" do
    setup do
      {:ok, pid} = Sup.init_user({"frank", self()})
      ExBanking.deposit("frank", 100, "USD")
      assert_receive {:"$gen_cast", {:ok, 100.0}}, 1_000

      on_exit(fn ->
        Process.exit(pid, :stop)
      end)

      :ok
    end

    @tag :reqular
    test "gets balance successfully" do
      ExBanking.get_balance("frank", "USD")
      assert_receive {:"$gen_cast", {:ok, 100.0}}, 1_000
    end

    @tag :reqular
    test "returns error if user does not exist" do
      assert ExBanking.get_balance("george", "USD") == {:error, :user_does_not_exist}
    end

    @tag :reqular
    test "returns error with invalid arguments" do
      assert ExBanking.get_balance("frank", 123) == {:error, :wrong_arguments}
    end
  end

  describe "send/4" do
    setup do
      {:ok, pid} = Sup.init_user({"hank", self()})
      {:ok, pid2} = Sup.init_user({"ian", self()})
      ExBanking.deposit("hank", 100, "USD")
      assert_receive {:"$gen_cast", {:ok, 100.0}}, 1_000

      on_exit(fn ->
        Process.exit(pid, :stop)
        Process.exit(pid2, :stop)
      end)

      :ok
    end

    @tag :reqular
    test "sends money successfully" do
      ExBanking.send("hank", "ian", 49, "USD")
      assert_receive {:"$gen_cast", {:ok, 51.0, 49.0}}, 1_000
    end

    @tag :reqular
    test "returns error if not enough money" do
      ExBanking.send("hank", "ian", 100.01, "USD")
      assert_receive {:"$gen_cast", {:error, :not_enough_money}}, 1_000
    end

    @tag :reqular
    test "returns error if sender does not exist" do
      assert ExBanking.send("john", "ian", 50, "USD") == {:error, :sender_does_not_exist}
    end

    @tag :reqular
    test "returns error if receiver does not exist" do
      assert ExBanking.send("hank", "john", 50, "USD") == {:error, :receiver_does_not_exist}
    end

    @tag :reqular
    test "returns error with invalid arguments" do
      assert ExBanking.send("hank", "ian", -50, "USD") == {:error, :wrong_arguments}
      assert ExBanking.send("hank", "ian", 50, 123) == {:error, :wrong_arguments}
    end
  end
end

defmodule Medishop.StripeServiceTest do
  use Medishop.DataCase, async: false
  alias Medishop.StripeService

  import Req.Test

  setup do
    Application.put_env(:medishop, :stripe, %{secret_key: "sk_test_your_secret"})
    :ok
  end

  test "create_customer/1 successfully creates a Stripe customer" do
    stub(Medishop.StripeService, fn conn ->
      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      assert body == "name=Test+Org&email=test%40example.com"
      Req.Test.json(conn, %{"id" => "cus_new_123"})
    end)

    customer_attrs = %{name: "Test Org", email: "test@example.com"}
    assert {:ok, %{"id" => "cus_new_123"}} = StripeService.create_customer(customer_attrs)
  end

  test "create_customer/1 returns error on Stripe API failure" do
    stub(Medishop.StripeService, fn conn ->
      # Manually send 400 response
      Plug.Conn.send_resp(conn, 400, Jason.encode!(%{"error" => %{"message" => "Invalid card details"}}))
    end)

    customer_attrs = %{name: "Test Org"}
    assert {:error, "Invalid card details"} = StripeService.create_customer(customer_attrs)
  end

  test "create_customer/1 returns error if secret key is not configured" do
    Application.put_env(:medishop, :stripe, %{secret_key: nil})

    customer_attrs = %{name: "Test Org"}

    assert {:error, "Stripe secret key not configured."} =
             StripeService.create_customer(customer_attrs)

    # Reset the config for other tests
    Application.put_env(:medishop, :stripe, %{secret_key: "sk_test_your_secret"})
  end
end
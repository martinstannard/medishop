defmodule Medishop.StripeService do
  @moduledoc """
  Service module for interacting with the Stripe API.
  """

  @base_url "https://api.stripe.com/v1"

  @doc """
  Creates a new customer in Stripe.
  """
  def create_customer(customer_attrs) do
    with {:ok, response} <- request([
           method: :post,
           url: "/customers",
           body: URI.encode_query(customer_attrs)
         ]) do
      process_stripe_response(response)
    end
  end

  def create_setup_intent(customer_id) do
    with {:ok, response} <- request([
           method: :post,
           url: "/setup_intents",
           body: URI.encode_query(%{customer: customer_id})
         ]) do
      process_stripe_response(response)
    end
  end

  def list_payment_methods(customer_id) do
    with {:ok, response} <- request([
           method: :get,
           url: "/payment_methods",
           params: [customer: customer_id, type: "card"]
         ]) do
      process_stripe_response(response)
    end
  end

  def detach_payment_method(payment_method_id) do
    with {:ok, response} <- request([
           method: :post,
           url: "/payment_methods/#{payment_method_id}/detach"
         ]) do
      process_stripe_response(response)
    end
  end

  defp request(req_options) do
    secret_key = Application.get_env(:medishop, :stripe)[:secret_key]

    if is_nil(secret_key) do
      {:error, "Stripe secret key not configured."}
    else
      [
        base_url: @base_url,
        headers: [
          {"Content-Type", "application/x-www-form-urlencoded"},
          {"Authorization", "Bearer " <> secret_key}
        ]
      ]
      |> Keyword.merge(req_options)
      |> Keyword.merge(Application.get_env(:medishop, :stripe_req_options, []))
      |> Req.request()
    end
  end

  defp process_stripe_response(%Req.Response{status: 200, body: body}) when is_map(body) do
    {:ok, body}
  end

  defp process_stripe_response(%Req.Response{status: 200, body: body}) do
    case Jason.decode(body) do
      {:ok, decoded_body} ->
        {:ok, decoded_body}

      _ ->
        {:error, "Invalid Stripe response."}
    end
  end

  defp process_stripe_response(%Req.Response{status: status, body: body})
       when status >= 400 and is_map(body) do
    case body do
      %{"error" => %{"message" => message}} ->
        {:error, message}

      _ ->
        {:error, "Stripe API error: #{status}"}
    end
  end

  defp process_stripe_response(%Req.Response{status: status, body: body}) when status >= 400 do
    case Jason.decode(body) do
      {:ok, %{"error" => %{"message" => message}}} ->
        {:error, message}

      _ ->
        {:error, "Stripe API error: #{status}"}
    end
  end
end

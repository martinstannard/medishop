defmodule MedishopWeb.OrderPDFController do
  use MedishopWeb, :controller

  alias Medishop.Shop

  def show(conn, %{"id" => order_id}) do
    user = conn.assigns[:current_user]

    case Shop.get_order(order_id, load: [:location, :user, order_items: [:product]]) do
      {:ok, order} ->
        # Verify user owns this order
        if order.user_id == user.id do
          # Generate PDF HTML
          html = generate_pdf_html(order)

          conn
          |> put_resp_content_type("text/html")
          |> put_resp_header("content-disposition", ~s(inline; filename="order-#{order.order_number}.html"))
          |> send_resp(200, html)
        else
          conn
          |> put_flash(:error, "You don't have permission to view this order")
          |> redirect(to: "/dashboard")
        end

      {:error, _} ->
        conn
        |> put_flash(:error, "Order not found")
        |> redirect(to: "/dashboard")
    end
  end

  defp generate_pdf_html(order) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <title>Order #{order.order_number}</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          padding: 40px;
          color: #1f2937;
        }
        .header {
          display: flex;
          justify-content: space-between;
          align-items: start;
          margin-bottom: 40px;
          padding-bottom: 20px;
          border-bottom: 2px solid #e5e7eb;
        }
        .logo {
          font-size: 28px;
          font-weight: bold;
          color: #2563eb;
        }
        .order-number {
          font-size: 24px;
          font-weight: bold;
        }
        .section {
          margin-bottom: 30px;
        }
        .section-title {
          font-size: 18px;
          font-weight: 600;
          margin-bottom: 12px;
          color: #374151;
        }
        .info-grid {
          display: grid;
          grid-template-columns: repeat(2, 1fr);
          gap: 20px;
          margin-bottom: 20px;
        }
        .info-item {
          padding: 12px;
          background: #f9fafb;
          border-radius: 8px;
        }
        .info-label {
          font-size: 12px;
          color: #6b7280;
          margin-bottom: 4px;
        }
        .info-value {
          font-size: 14px;
          font-weight: 500;
        }
        table {
          width: 100%;
          border-collapse: collapse;
          margin-top: 12px;
        }
        thead {
          background: #f3f4f6;
        }
        th {
          padding: 12px;
          text-align: left;
          font-size: 12px;
          font-weight: 600;
          color: #374151;
          border-bottom: 2px solid #e5e7eb;
        }
        td {
          padding: 12px;
          border-bottom: 1px solid #e5e7eb;
          font-size: 14px;
        }
        .text-right {
          text-align: right;
        }
        .totals {
          margin-top: 20px;
          display: flex;
          justify-content: flex-end;
        }
        .totals-box {
          width: 300px;
          padding: 20px;
          background: #f9fafb;
          border-radius: 8px;
        }
        .total-row {
          display: flex;
          justify-content: space-between;
          margin-bottom: 12px;
          font-size: 14px;
        }
        .total-row.grand {
          font-size: 18px;
          font-weight: bold;
          padding-top: 12px;
          border-top: 2px solid #e5e7eb;
        }
        .status-badge {
          display: inline-block;
          padding: 4px 12px;
          border-radius: 12px;
          font-size: 12px;
          font-weight: 600;
        }
        .status-pending { background: #fef3c7; color: #92400e; }
        .status-confirmed { background: #dbeafe; color: #1e40af; }
        .status-shipped { background: #e9d5ff; color: #6b21a8; }
        .status-delivered { background: #d1fae5; color: #065f46; }
        .status-cancelled { background: #fee2e2; color: #991b1b; }
        @media print {
          body { padding: 20px; }
        }
      </style>
    </head>
    <body>
      <div class="header">
        <div>
          <div class="logo">Medishop</div>
          <div style="color: #6b7280; margin-top: 4px;">Healthcare Supply Platform</div>
        </div>
        <div style="text-align: right;">
          <div class="order-number">Order #{order.order_number}</div>
          <div class="status-badge status-#{order.status}">#{Phoenix.Naming.humanize(order.status)}</div>
        </div>
      </div>

      <div class="info-grid">
        <div class="info-item">
          <div class="info-label">Order Date</div>
          <div class="info-value">#{Calendar.strftime(order.placed_at, "%B %d, %Y at %I:%M %p")}</div>
        </div>
        <div class="info-item">
          <div class="info-label">Location</div>
          <div class="info-value">#{order.location.name}</div>
        </div>
      </div>

      #{if order.notes do
        """
        <div class="section">
          <div class="section-title">Order Notes</div>
          <div style="padding: 12px; background: #f9fafb; border-radius: 8px;">
            #{order.notes}
          </div>
        </div>
        """
      else
        ""
      end}

      <div class="section">
        <div class="section-title">Order Items</div>
        <table>
          <thead>
            <tr>
              <th>Product</th>
              <th class="text-right">Quantity</th>
              <th class="text-right">Unit Price</th>
              <th class="text-right">Line Total</th>
            </tr>
          </thead>
          <tbody>
            #{Enum.map_join(order.order_items, fn item ->
              """
              <tr>
                <td>
                  <div style="font-weight: 500;">#{item.product.title}</div>
                  <div style="font-size: 12px; color: #6b7280;">SKU: #{item.product.sku}</div>
                </td>
                <td class="text-right">#{item.quantity}</td>
                <td class="text-right">$#{Decimal.to_string(item.unit_price, :normal)}</td>
                <td class="text-right">$#{Decimal.to_string(item.line_total, :normal)}</td>
              </tr>
              """
            end)}
          </tbody>
        </table>
      </div>

      <div class="totals">
        <div class="totals-box">
          <div class="total-row">
            <span>Subtotal</span>
            <span>$#{Decimal.to_string(order.subtotal, :normal)}</span>
          </div>
          <div class="total-row grand">
            <span>Total</span>
            <span>$#{Decimal.to_string(order.total, :normal)}</span>
          </div>
        </div>
      </div>

      <div style="margin-top: 60px; padding-top: 20px; border-top: 1px solid #e5e7eb; font-size: 12px; color: #6b7280; text-align: center;">
        <p>Thank you for your order!</p>
        <p style="margin-top: 4px;">If you have any questions, please contact us.</p>
      </div>

      <script>
        // Auto-print on load (optional)
        // window.onload = function() { window.print(); }
      </script>
    </body>
    </html>
    """
  end
end

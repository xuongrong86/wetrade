defmodule TestfunctiondbWeb.PageController do
  use TestfunctiondbWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def add(conn, _params) do
    render(conn, "add.html", a: nil, b: nil, sum_a_b: "")
  end

  def sum(conn, params) do
    IO.inspect(params)

    # call function add(a, b) in database
    a = case params["a"] do
      nil ->
        0
      "" ->
        0
      _ ->
        String.to_integer(params["a"])
    end

    b = case params["b"] do
      nil ->
        0
        "" ->
          0
      _ ->
        String.to_integer(params["b"])
    end

    result = Ecto.Adapters.SQL.query!(Testfunctiondb.Repo, "SELECT * FROM get_sum($1, $2)", [a, b])

    sum = result.rows
          # get first row
          |> List.first()
          # [3]
          |> Enum.at(0)

    render(conn, "add.html", a: a, b: b, sum_a_b: sum)
  end
end

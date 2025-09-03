defmodule ResearchPlatformWeb.PaperLiveTest do
  use ResearchPlatformWeb.ConnCase

  import Phoenix.LiveViewTest
  import ResearchPlatform.PapersFixtures

  @create_attrs %{metadata: %{}, keywords: ["option1", "option2"], title: "some title", abstract: "some abstract", authors: ["option1", "option2"], file_path: "some file_path", file_size: 42}
  @update_attrs %{metadata: %{}, keywords: ["option1"], title: "some updated title", abstract: "some updated abstract", authors: ["option1"], file_path: "some updated file_path", file_size: 43}
  @invalid_attrs %{metadata: nil, keywords: [], title: nil, abstract: nil, authors: [], file_path: nil, file_size: nil}

  setup :register_and_log_in_user

  defp create_paper(%{scope: scope}) do
    paper = paper_fixture(scope)

    %{paper: paper}
  end

  describe "Index" do
    setup [:create_paper]

    test "lists all papers", %{conn: conn, paper: paper} do
      {:ok, _index_live, html} = live(conn, ~p"/papers")

      assert html =~ "Listing Papers"
      assert html =~ paper.title
    end

    test "saves new paper", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/papers")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Paper")
               |> render_click()
               |> follow_redirect(conn, ~p"/papers/new")

      assert render(form_live) =~ "New Paper"

      assert form_live
             |> form("#paper-form", paper: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#paper-form", paper: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/papers")

      html = render(index_live)
      assert html =~ "Paper created successfully"
      assert html =~ "some title"
    end

    test "updates paper in listing", %{conn: conn, paper: paper} do
      {:ok, index_live, _html} = live(conn, ~p"/papers")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#papers-#{paper.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/papers/#{paper}/edit")

      assert render(form_live) =~ "Edit Paper"

      assert form_live
             |> form("#paper-form", paper: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#paper-form", paper: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/papers")

      html = render(index_live)
      assert html =~ "Paper updated successfully"
      assert html =~ "some updated title"
    end

    test "deletes paper in listing", %{conn: conn, paper: paper} do
      {:ok, index_live, _html} = live(conn, ~p"/papers")

      assert index_live |> element("#papers-#{paper.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#papers-#{paper.id}")
    end
  end

  describe "Show" do
    setup [:create_paper]

    test "displays paper", %{conn: conn, paper: paper} do
      {:ok, _show_live, html} = live(conn, ~p"/papers/#{paper}")

      assert html =~ "Show Paper"
      assert html =~ paper.title
    end

    test "updates paper and returns to show", %{conn: conn, paper: paper} do
      {:ok, show_live, _html} = live(conn, ~p"/papers/#{paper}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/papers/#{paper}/edit?return_to=show")

      assert render(form_live) =~ "Edit Paper"

      assert form_live
             |> form("#paper-form", paper: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#paper-form", paper: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/papers/#{paper}")

      html = render(show_live)
      assert html =~ "Paper updated successfully"
      assert html =~ "some updated title"
    end
  end
end

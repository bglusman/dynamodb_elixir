defmodule Dynamo.Connection.Auth.CR do
  @moduledoc false
  import Dynamo.Connection.Utils

  def auth({username, password}, s) do
    case sync_command(-2, [getnonce: 1], s) do
      {:ok, %{"nonce" => nonce, "ok" => 1.0}} ->
        nonce(nonce, username, password, s)
      {:tcp_error, _} = error ->
        error
    end
  end

  defp nonce(nonce, username, password, s) do
    digest = digest(nonce, username, password)
    command = [authenticate: 1, user: username, nonce: nonce, key: digest]

    case sync_command(-3, command, s) do
      {:ok, %{"ok" => 1.0}} ->
        :ok
      {:ok, %{"ok" => 0.0, "errmsg" => reason, "code" => code}} ->
        {:error, %Dynamo.Error{message: "auth failed for '#{username}': #{reason}", code: code}}
      {:ok, nil} ->
        {:error, %Dynamo.Error{message: "auth failed for '#{username}'"}}
      {:tcp_error, _} = error ->
        error
    end
  end
end

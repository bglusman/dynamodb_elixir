ExUnit.start()

# {string, 0} = System.cmd("dynamod", ~w'--version')
# ["db version v" <> version, _] = String.split(string, "\n", parts: 2)

# version =
#   version
#   |> String.split(".")
#   |> Enum.map(&elem(Integer.parse(&1), 0))
#   |> List.to_tuple

# {_, 0} = System.cmd("dynamo", ~w'dynamodb_test --eval db.dropDatabase()')
# {_, 0} = System.cmd("dynamo", ~w'dynamodb_test2 --eval db.dropDatabase()')

# if version < {2, 6, 0} do
#   {_, 0} = System.cmd("dynamo", ~w'dynamodb_test --eval db.addUser({user:"dynamodb_user",pwd:"dynamodb_user",roles:[]})')
#   {_, 0} = System.cmd("dynamo", ~w'dynamodb_test --eval db.addUser({user:"dynamodb_user2",pwd:"dynamodb_user2",roles:[]})')
# else
#   {_, _} = System.cmd("dynamo", ~w'dynamodb_test --eval db.dropUser("dynamodb_user")')
#   {_, _} = System.cmd("dynamo", ~w'dynamodb_test --eval db.dropUser("dynamodb_user2")')
#   {_, 0} = System.cmd("dynamo", ~w'dynamodb_test --eval db.createUser({user:"dynamodb_user",pwd:"dynamodb_user",roles:[]})')
#   {_, 0} = System.cmd("dynamo", ~w'dynamodb_test --eval db.createUser({user:"dynamodb_user2",pwd:"dynamodb_user2",roles:[]})')
# end

defmodule DynamoTest.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import DynamoTest.Case
    end
  end

  def capture_log(fun) do
    Logger.remove_backend(:console)
    fun.()
    Logger.add_backend(:console, flush: true)
  end

  defmacro unique_name do
    {function, _arity} = __CALLER__.function
    "#{__CALLER__.module}.#{function}"
  end
end

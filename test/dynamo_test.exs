defmodule Dynamo.Test do
  use DynamoTest.Case, async: true

  defmodule Pool do
    use Dynamo.Pool, name: __MODULE__, adapter: Dynamo.Pool.Poolboy
  end

  defmodule LoggingPool do
    use Dynamo.Pool, name: __MODULE__, adapter: Dynamo.Pool.Poolboy

    def log(return, _queue_time, _query_time, fun, args) do
      Process.put(:last_log, {fun, args})
      return
    end
  end

  setup_all do
    assert {:ok, _} = Pool.start_link(database: "dynamodb_test")
    assert {:ok, _} = LoggingPool.start_link(database: "dynamodb_test")
    :ok
  end

  test "run_command with an error" do
    assert_raise Dynamo.Error, fn ->
      Dynamo.run_command(Pool, %{ drop: "unexisting-database" })
    end
  end

  test "aggregate" do
    coll = unique_name

    assert {:ok, _} = Dynamo.insert_one(Pool, coll, %{foo: 42})
    assert {:ok, _} = Dynamo.insert_one(Pool, coll, %{foo: 43})
    assert {:ok, _} = Dynamo.insert_one(Pool, coll, %{foo: 44})
    assert {:ok, _} = Dynamo.insert_one(Pool, coll, %{foo: 45})

    assert [%{"foo" => 42}, %{"foo" => 43}, %{"foo" => 44}, %{"foo" => 45}] =
           Dynamo.aggregate(Pool, coll, []) |> Enum.to_list

    assert []               = Dynamo.aggregate(Pool, coll, []) |> Enum.take(0)
    assert []               = Dynamo.aggregate(Pool, coll, []) |> Enum.drop(4)
    assert [%{"foo" => 42}] = Dynamo.aggregate(Pool, coll, []) |> Enum.take(1)
    assert [%{"foo" => 45}] = Dynamo.aggregate(Pool, coll, []) |> Enum.drop(3)

    assert []               = Dynamo.aggregate(Pool, coll, [], use_cursor: false) |> Enum.take(0)
    assert []               = Dynamo.aggregate(Pool, coll, [], use_cursor: false) |> Enum.drop(4)
    assert [%{"foo" => 42}] = Dynamo.aggregate(Pool, coll, [], use_cursor: false) |> Enum.take(1)
    assert [%{"foo" => 45}] = Dynamo.aggregate(Pool, coll, [], use_cursor: false) |> Enum.drop(3)

    assert []               = Dynamo.aggregate(Pool, coll, [], batch_size: 1) |> Enum.take(0)
    assert []               = Dynamo.aggregate(Pool, coll, [], batch_size: 1) |> Enum.drop(4)
    assert [%{"foo" => 42}] = Dynamo.aggregate(Pool, coll, [], batch_size: 1) |> Enum.take(1)
    assert [%{"foo" => 45}] = Dynamo.aggregate(Pool, coll, [], batch_size: 1) |> Enum.drop(3)
  end

  test "count" do
    coll = unique_name

    assert 0 = Dynamo.count(Pool, coll, [])

    assert {:ok, _} = Dynamo.insert_one(Pool, coll, %{foo: 42})
    assert {:ok, _} = Dynamo.insert_one(Pool, coll, %{foo: 43})

    assert 2 = Dynamo.count(Pool, coll, %{})
    assert 1 = Dynamo.count(Pool, coll, %{foo: 42})
  end

  test "distinct" do
    coll = unique_name

    assert [] = Dynamo.distinct(Pool, coll, "foo", %{})

    assert {:ok, _} = Dynamo.insert_one(Pool, coll, %{foo: 42})
    assert {:ok, _} = Dynamo.insert_one(Pool, coll, %{foo: 42})
    assert {:ok, _} = Dynamo.insert_one(Pool, coll, %{foo: 43})

    assert [42, 43] = Dynamo.distinct(Pool, coll, "foo", %{})
    assert [42]     = Dynamo.distinct(Pool, coll, "foo", %{foo: 42})
  end

  test "find" do
    coll = unique_name

    assert [] = Dynamo.find(Pool, coll, %{}) |> Enum.to_list

    assert {:ok, _} = Dynamo.insert_one(Pool, coll, %{foo: 42, bar: 1})
    assert {:ok, _} = Dynamo.insert_one(Pool, coll, %{foo: 43, bar: 2})
    assert {:ok, _} = Dynamo.insert_one(Pool, coll, %{foo: 44, bar: 3})

    assert [%{"foo" => 42}, %{"foo" => 43}, %{"foo" => 44}] =
           Dynamo.find(Pool, coll, %{}) |> Enum.to_list

    # Dynamo is weird with batch_size=1
    assert [%{"foo" => 42}] = Dynamo.find(Pool, coll, %{}, batch_size: 1) |> Enum.to_list

    assert [%{"foo" => 42}, %{"foo" => 43}, %{"foo" => 44}] =
           Dynamo.find(Pool, coll, %{}, batch_size: 2) |> Enum.to_list

    assert [%{"foo" => 42}, %{"foo" => 43}] =
           Dynamo.find(Pool, coll, %{}, limit: 2) |> Enum.to_list

    assert [%{"foo" => 42}, %{"foo" => 43}] =
           Dynamo.find(Pool, coll, %{}, batch_size: 2, limit: 2) |> Enum.to_list

    assert [%{"foo" => 42}] =
           Dynamo.find(Pool, coll, %{bar: 1}) |> Enum.to_list

    assert [%{"bar" => 1}, %{"bar" => 2}, %{"bar" => 3}] =
           Dynamo.find(Pool, coll, %{}, projection: %{bar: 1}) |> Enum.to_list

    assert [%{"bar" => 1}] =
           Dynamo.find(Pool, coll, %{"$query": %{foo: 42}}, projection: %{bar: 1}) |> Enum.to_list

    assert [%{"foo" => 44}, %{"foo" => 43}] =
      Dynamo.find(Pool, coll, %{}, sort: [foo: -1], batch_size: 2, limit: 2) |> Enum.to_list
  end

  test "insert_one" do
    coll = unique_name

    assert_raise ArgumentError, fn ->
      Dynamo.insert_one(Pool, coll, [%{foo: 42, bar: 1}])
    end

    assert {:ok, result} = Dynamo.insert_one(Pool, coll, %{foo: 42})
    assert %Dynamo.InsertOneResult{inserted_id: id} = result

    assert [%{"_id" => ^id, "foo" => 42}] = Dynamo.find(Pool, coll, %{_id: id}) |> Enum.to_list

    assert :ok = Dynamo.insert_one(Pool, coll, %{}, w: 0)
  end

  test "insert_many" do
    coll = unique_name

    assert_raise ArgumentError, fn ->
      Dynamo.insert_many(Pool, coll, %{foo: 42, bar: 1})
    end

    assert {:ok, result} = Dynamo.insert_many(Pool, coll, [%{foo: 42}, %{foo: 43}])
    assert %Dynamo.InsertManyResult{inserted_ids: %{0 => id0, 1 => id1}} = result

    assert [%{"_id" => ^id0, "foo" => 42}] = Dynamo.find(Pool, coll, %{_id: id0}) |> Enum.to_list
    assert [%{"_id" => ^id1, "foo" => 43}] = Dynamo.find(Pool, coll, %{_id: id1}) |> Enum.to_list

    assert :ok = Dynamo.insert_many(Pool, coll, [%{}], w: 0)
  end

  test "delete_one" do
    coll = unique_name

    assert {:ok, _} = Dynamo.insert_many(Pool, coll, [%{foo: 42}, %{foo: 42}, %{foo: 43}])

    assert {:ok, %Dynamo.DeleteResult{deleted_count: 1}} = Dynamo.delete_one(Pool, coll, %{foo: 42})
    assert [%{"foo" => 42}] = Dynamo.find(Pool, coll, %{foo: 42}) |> Enum.to_list

    assert {:ok, %Dynamo.DeleteResult{deleted_count: 1}} = Dynamo.delete_one(Pool, coll, %{foo: 42})
    assert [] = Dynamo.find(Pool, coll, %{foo: 42}) |> Enum.to_list

    assert {:ok, %Dynamo.DeleteResult{deleted_count: 0}} = Dynamo.delete_one(Pool, coll, %{foo: 42})
    assert [%{"foo" => 43}] = Dynamo.find(Pool, coll, %{foo: 43}) |> Enum.to_list
  end

  test "delete_many" do
    coll = unique_name

    assert {:ok, _} = Dynamo.insert_many(Pool, coll, [%{foo: 42}, %{foo: 42}, %{foo: 43}])

    assert {:ok, %Dynamo.DeleteResult{deleted_count: 2}} = Dynamo.delete_many(Pool, coll, %{foo: 42})
    assert [] = Dynamo.find(Pool, coll, %{foo: 42}) |> Enum.to_list

    assert {:ok, %Dynamo.DeleteResult{deleted_count: 0}} = Dynamo.delete_one(Pool, coll, %{foo: 42})
    assert [%{"foo" => 43}] = Dynamo.find(Pool, coll, %{foo: 43}) |> Enum.to_list
  end

  test "replace_one" do
    coll = unique_name

    assert_raise ArgumentError, fn ->
      Dynamo.replace_one(Pool, coll, %{foo: 42}, %{"$set": %{foo: 0}})
    end

    assert {:ok, _} = Dynamo.insert_many(Pool, coll, [%{foo: 42}, %{foo: 42}, %{foo: 43}])

    assert {:ok, %Dynamo.UpdateResult{matched_count: 1, modified_count: 1, upserted_id: nil}} =
           Dynamo.replace_one(Pool, coll, %{foo: 42}, %{foo: 0})

    assert [_] = Dynamo.find(Pool, coll, %{foo: 0}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 42}) |> Enum.to_list

    assert {:ok, %Dynamo.UpdateResult{matched_count: 0, modified_count: 1, upserted_id: id}} =
           Dynamo.replace_one(Pool, coll, %{foo: 50}, %{foo: 0}, upsert: true)
    assert [_] = Dynamo.find(Pool, coll, %{_id: id}) |> Enum.to_list

    assert {:ok, %Dynamo.UpdateResult{matched_count: 1, modified_count: 1, upserted_id: nil}} =
           Dynamo.replace_one(Pool, coll, %{foo: 43}, %{foo: 1}, upsert: true)
    assert [] = Dynamo.find(Pool, coll, %{foo: 43}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 1}) |> Enum.to_list
  end

  test "update_one" do
    coll = unique_name

    assert_raise ArgumentError, fn ->
      Dynamo.update_one(Pool, coll, %{foo: 42}, %{foo: 0})
    end

    assert {:ok, _} = Dynamo.insert_many(Pool, coll, [%{foo: 42}, %{foo: 42}, %{foo: 43}])

    assert {:ok, %Dynamo.UpdateResult{matched_count: 1, modified_count: 1, upserted_id: nil}} =
           Dynamo.update_one(Pool, coll, %{foo: 42}, %{"$set": %{foo: 0}})

    assert [_] = Dynamo.find(Pool, coll, %{foo: 0}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 42}) |> Enum.to_list

    assert {:ok, %Dynamo.UpdateResult{matched_count: 0, modified_count: 1, upserted_id: id}} =
           Dynamo.update_one(Pool, coll, %{foo: 50}, %{"$set": %{foo: 0}}, upsert: true)
    assert [_] = Dynamo.find(Pool, coll, %{_id: id}) |> Enum.to_list

    assert {:ok, %Dynamo.UpdateResult{matched_count: 1, modified_count: 1, upserted_id: nil}} =
           Dynamo.update_one(Pool, coll, %{foo: 43}, %{"$set": %{foo: 1}}, upsert: true)
    assert [] = Dynamo.find(Pool, coll, %{foo: 43}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 1}) |> Enum.to_list
  end

  test "update_many" do
    coll = unique_name

    assert_raise ArgumentError, fn ->
      Dynamo.update_many(Pool, coll, %{foo: 42}, %{foo: 0})
    end

    assert {:ok, _} = Dynamo.insert_many(Pool, coll, [%{foo: 42}, %{foo: 42}, %{foo: 43}])

    assert {:ok, %Dynamo.UpdateResult{matched_count: 2, modified_count: 2, upserted_id: nil}} =
           Dynamo.update_many(Pool, coll, %{foo: 42}, %{"$set": %{foo: 0}})

    assert [_, _] = Dynamo.find(Pool, coll, %{foo: 0}) |> Enum.to_list
    assert [] = Dynamo.find(Pool, coll, %{foo: 42}) |> Enum.to_list

    assert {:ok, %Dynamo.UpdateResult{matched_count: 0, modified_count: 1, upserted_id: id}} =
           Dynamo.update_many(Pool, coll, %{foo: 50}, %{"$set": %{foo: 0}}, upsert: true)
    assert [_] = Dynamo.find(Pool, coll, %{_id: id}) |> Enum.to_list

    assert {:ok, %Dynamo.UpdateResult{matched_count: 1, modified_count: 1, upserted_id: nil}} =
           Dynamo.update_many(Pool, coll, %{foo: 43}, %{"$set": %{foo: 1}}, upsert: true)
    assert [] = Dynamo.find(Pool, coll, %{foo: 43}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 1}) |> Enum.to_list
  end

  test "save_one" do
    coll = unique_name
    id = Dynamo.IdServer.new

    assert {:ok, %Dynamo.SaveOneResult{matched_count: 0, modified_count: 0, upserted_id: %BSON.ObjectId{}}} =
           Dynamo.save_one(Pool, coll, %{foo: 42})
    assert [_] = Dynamo.find(Pool, coll, %{foo: 42}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveOneResult{matched_count: 0, modified_count: 0, upserted_id: %BSON.ObjectId{}}} =
           Dynamo.save_one(Pool, coll, %{foo: 42})
    assert [_, _] = Dynamo.find(Pool, coll, %{foo: 42}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveOneResult{matched_count: 0, modified_count: 1, upserted_id: %BSON.ObjectId{}}} =
           Dynamo.save_one(Pool, coll, %{_id: id, foo: 43})
    assert [_] = Dynamo.find(Pool, coll, %{foo: 43}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveOneResult{matched_count: 1, modified_count: 1, upserted_id: nil}} =
           Dynamo.save_one(Pool, coll, %{_id: id, foo: 44})
    assert [] = Dynamo.find(Pool, coll, %{foo: 43}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 44}) |> Enum.to_list
  end

  test "save_many ordered single" do
    coll = unique_name
    id = Dynamo.IdServer.new

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 0, modified_count: 0, upserted_ids: %{0 => %BSON.ObjectId{}}}} =
           Dynamo.save_many(Pool, coll, [%{foo: 42}])
    assert [_] = Dynamo.find(Pool, coll, %{foo: 42}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 0, modified_count: 0, upserted_ids: %{0 => %BSON.ObjectId{}}}} =
           Dynamo.save_many(Pool, coll, [%{foo: 42}])
    assert [_, _] = Dynamo.find(Pool, coll, %{foo: 42}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 0, modified_count: 1, upserted_ids: %{0 => %BSON.ObjectId{}}}} =
           Dynamo.save_many(Pool, coll, [%{_id: id, foo: 43}])
    assert [_] = Dynamo.find(Pool, coll, %{foo: 43}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 1, modified_count: 1, upserted_ids: %{}}} =
           Dynamo.save_many(Pool, coll, [%{_id: id, foo: 44}])
    assert [] = Dynamo.find(Pool, coll, %{foo: 43}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 44}) |> Enum.to_list
  end

  test "save_many ordered multi" do
    coll = unique_name
    id1 = Dynamo.IdServer.new
    id2 = Dynamo.IdServer.new
    id3 = Dynamo.IdServer.new
    id4 = Dynamo.IdServer.new
    id5 = Dynamo.IdServer.new

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 0, modified_count: 0,
                                       upserted_ids: %{0 => %BSON.ObjectId{}, 1 => %BSON.ObjectId{}}}} =
           Dynamo.save_many(Pool, coll, [%{foo: 42}, %{foo: 43}])
    assert [_] = Dynamo.find(Pool, coll, %{foo: 42}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 43}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 0, modified_count: 2,
                                       upserted_ids: %{0 => %BSON.ObjectId{}, 1 => %BSON.ObjectId{}}}} =
           Dynamo.save_many(Pool, coll, [%{_id: id1, foo: 44}, %{_id: id2, foo: 45}])
    assert [_] = Dynamo.find(Pool, coll, %{foo: 44}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 45}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 2, modified_count: 2, upserted_ids: %{}}} =
           Dynamo.save_many(Pool, coll, [%{_id: id1, foo: 46}, %{_id: id1, foo: 46}])
    assert [] = Dynamo.find(Pool, coll, %{foo: 44}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 46}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 0, modified_count: 1,
                                       upserted_ids: %{0 => %BSON.ObjectId{}, 1 => %BSON.ObjectId{}, 2 => %BSON.ObjectId{}}}} =
           Dynamo.save_many(Pool, coll, [%{foo: 47}, %{_id: id3, foo: 48}, %{foo: 49}], ordered: false)
    assert [_] = Dynamo.find(Pool, coll, %{foo: 47}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 48}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 49}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 0, modified_count: 2,
                                       upserted_ids: %{0 => %BSON.ObjectId{}, 1 => %BSON.ObjectId{}, 2 => %BSON.ObjectId{}}}} =
           Dynamo.save_many(Pool, coll, [%{_id: id4, foo: 50}, %{foo: 51}, %{_id: id5, foo: 52}], ordered: false)
    assert [_] = Dynamo.find(Pool, coll, %{foo: 50}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 51}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 52}) |> Enum.to_list
  end

  test "save_many unordered single" do
    coll = unique_name
    id = Dynamo.IdServer.new

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 0, modified_count: 0, upserted_ids: %{0 => %BSON.ObjectId{}}}} =
           Dynamo.save_many(Pool, coll, [%{foo: 42}], ordered: false)
    assert [_] = Dynamo.find(Pool, coll, %{foo: 42}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 0, modified_count: 0, upserted_ids: %{0 => %BSON.ObjectId{}}}} =
           Dynamo.save_many(Pool, coll, [%{foo: 42}], ordered: false)
    assert [_, _] = Dynamo.find(Pool, coll, %{foo: 42}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 0, modified_count: 1, upserted_ids: %{0 => %BSON.ObjectId{}}}} =
           Dynamo.save_many(Pool, coll, [%{_id: id, foo: 43}], ordered: false)
    assert [_] = Dynamo.find(Pool, coll, %{foo: 43}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 1, modified_count: 1, upserted_ids: %{}}} =
           Dynamo.save_many(Pool, coll, [%{_id: id, foo: 44}], ordered: false)
    assert [] = Dynamo.find(Pool, coll, %{foo: 43}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 44}) |> Enum.to_list
  end

  test "save_many unordered multi" do
    coll = unique_name
    id1 = Dynamo.IdServer.new
    id2 = Dynamo.IdServer.new
    id3 = Dynamo.IdServer.new
    id4 = Dynamo.IdServer.new
    id5 = Dynamo.IdServer.new

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 0, modified_count: 0,
                                       upserted_ids: %{0 => %BSON.ObjectId{}, 1 => %BSON.ObjectId{}}}} =
           Dynamo.save_many(Pool, coll, [%{foo: 42}, %{foo: 43}], ordered: false)
    assert [_] = Dynamo.find(Pool, coll, %{foo: 42}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 43}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 0, modified_count: 2,
                                       upserted_ids: %{0 => %BSON.ObjectId{}, 1 => %BSON.ObjectId{}}}} =
           Dynamo.save_many(Pool, coll, [%{_id: id1, foo: 44}, %{_id: id2, foo: 45}], ordered: false)
    assert [_] = Dynamo.find(Pool, coll, %{foo: 44}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 45}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 2, modified_count: 2, upserted_ids: %{}}} =
           Dynamo.save_many(Pool, coll, [%{_id: id1, foo: 46}, %{_id: id1, foo: 46}], ordered: false)
    assert [] = Dynamo.find(Pool, coll, %{foo: 44}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 46}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 0, modified_count: 1,
                                       upserted_ids: %{0 => %BSON.ObjectId{}, 1 => %BSON.ObjectId{}, 2 => %BSON.ObjectId{}}}} =
           Dynamo.save_many(Pool, coll, [%{foo: 47}, %{_id: id3, foo: 48}, %{foo: 49}], ordered: false)
    assert [_] = Dynamo.find(Pool, coll, %{foo: 47}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 48}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 49}) |> Enum.to_list

    assert {:ok, %Dynamo.SaveManyResult{matched_count: 0, modified_count: 2,
                                       upserted_ids: %{0 => %BSON.ObjectId{}, 1 => %BSON.ObjectId{}, 2 => %BSON.ObjectId{}}}} =
           Dynamo.save_many(Pool, coll, [%{_id: id4, foo: 50}, %{foo: 51}, %{_id: id5, foo: 52}], ordered: false)
    assert [_] = Dynamo.find(Pool, coll, %{foo: 50}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 51}) |> Enum.to_list
    assert [_] = Dynamo.find(Pool, coll, %{foo: 52}) |> Enum.to_list
  end

  test "logging" do
    coll = unique_name

    Dynamo.find(LoggingPool, coll, %{}, log: false) |> Enum.to_list
    refute Process.get(:last_log)

    Dynamo.find(LoggingPool, coll, %{}) |> Enum.to_list
    assert Process.get(:last_log) == {:find, [coll, %{}, nil, [batch_size: 1000]]}
  end

  # issue #19
  test "correctly pass options to cursor" do
    assert %Dynamo.Cursor{coll: "coll", opts: [no_cursor_timeout: true, skip: 10]} =
           Dynamo.find(Pool, "coll", %{}, skip: 10, cursor_timeout: false)
  end
end

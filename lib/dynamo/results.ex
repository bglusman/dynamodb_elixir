defmodule Dynamo.InsertOneResult do
  @moduledoc """
  The successful result struct of `Dynamo.insert_one/4`. Its fields are:

    * `:inserted_id` - The id of the inserted document
  """

  @type t :: %__MODULE__{
    inserted_id: nil | BSON.ObjectId.t
  }

  defstruct [:inserted_id]
end

defmodule Dynamo.InsertManyResult do
  @moduledoc """
  The successful result struct of `Dynamo.insert_many/4`. Its fields are:

    * `:inserted_ids` - The ids of the inserted documents
  """

  @type t :: %__MODULE__{
    inserted_ids: [BSON.ObjectId.t]
  }

  defstruct [:inserted_ids]
end

defmodule Dynamo.DeleteResult do
  @moduledoc """
  The successful result struct of `Dynamo.delete_one/4` and `Dynamo.delete_many/4`.
  Its fields are:

    * `:deleted_count` - Number of deleted documents
  """

  @type t :: %__MODULE__{
    deleted_count: non_neg_integer
  }

  defstruct [:deleted_count]
end

defmodule Dynamo.UpdateResult do
  @moduledoc """
  The successful result struct of `Dynamo.update_one/5`, `Dynamo.update_many/5`
  and `Dynamo.replace_one/5`. Its fields are:

    * `:matched_count` - Number of matched documents
    * `:modified_count` - Number of modified documents
    * `:upserted_id` - If the operation was an upsert, the upserted id
  """

  @type t :: %__MODULE__{
    matched_count: non_neg_integer,
    modified_count: non_neg_integer,
    upserted_id: nil | BSON.ObjectId.t
  }

  defstruct [:matched_count, :modified_count, :upserted_id]
end

defmodule Dynamo.SaveOneResult do
  @moduledoc """
  The successful result struct of `Dynamo.save_one/4`. Its fields are:

    * `:matched_count` - Number of matched documents
    * `:modified_count` - Number of modified documents
    * `:upserted_id` - If the operation was an upsert, the upserted id
  """

  @type t :: %__MODULE__{
    matched_count: non_neg_integer,
    modified_count: non_neg_integer,
    upserted_id: nil | BSON.ObjectId.t
  }

  defstruct [:matched_count, :modified_count, :upserted_id]
end

defmodule Dynamo.SaveManyResult do
  @moduledoc """
  The successful result struct of `Dynamo.save_many/4`. Its fields are:

    * `:matched_count` - Number of matched documents
    * `:modified_count` - Number of modified documents
    * `:upserted_ids` - If the operation was an upsert, the upserted ids
  """

  @type t :: %__MODULE__{
    matched_count: non_neg_integer,
    modified_count: non_neg_integer,
    upserted_ids: nil | BSON.ObjectId.t
  }

  defstruct [:matched_count, :modified_count, :upserted_ids]
end

defmodule Dynamo.ReadResult do
  @moduledoc false

  defstruct [
    :from,
    :num,
    :docs,
    :cursor_id
  ]
end

defmodule Dynamo.WriteResult do
  @moduledoc false

  # On 2.4 num_modified will always be nil

  defstruct [
    :type,
    :num_inserted,
    :num_matched,
    :num_modified,
    :num_removed,
    :upserted_id,
    :inserted_ids
  ]
end

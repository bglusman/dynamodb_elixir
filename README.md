Dynamodb
=======

[![Build Status](https://travis-ci.org/bglusman/dynamodb.svg?branch=master)](https://travis-ci.org/bglusman/dynamodb)
[![Inline docs](http://inch-ci.org/github/bglusman/dynamodb.svg)](http://inch-ci.org/github/bglusman/dynamodb)

## Adapted (hopefully someday) from https://github.com/ericmj/mongodb

## Features

  * Supports DynamoDB local and AWS
  * Connection pooling
  * Streaming cursors
  * Performant ObjectID generation

## Immediate Roadmap

  * Add timeouts for all calls
  * Bang and non-bang `Dynamo` functions
  * Move BSON encoding to client process
    - Make sure requests don't go over the 16mb limit
  * Replica sets
    - Block in client (and timeout) when waiting for new primary selection
  * Reconnect backoffs with https://github.com/ferd/backoff
  * Lazy connect

## Tentative Roadmap

  * SSL
  * Use meta-driver test suite
  * Server selection / Read preference
    - https://www.dynamodb.com/blog/post/server-selection-next-generation-dynamodb-drivers
    - http://docs.dynamodb.org/manual/reference/read-preference

## Data representation

    BSON             	Elixir
    ----------        	------
    double              0.0
    string              "Elixir"
    document            [{"key", "value"}] | %{"key" => "value"} *
    binary              %BSON.Binary{binary: <<42, 43>>, subtype: :generic}
    object id           %BSON.ObjectId{value: <<...>>}
    boolean             true | false
    UTC datetime        %BSON.DateTime{utc: ...}
    null                nil
    regex               %BSON.Regex{pattern: "..."}
    JavaScript          %BSON.JavaScript{code: "..."}
    integer             42
    symbol              "foo" **
    min key             :BSON_min
    max key             :BSON_max

* Since BSON documents are ordered Elixir maps cannot be used to fully represent them. This driver chose to accept both maps and lists of key-value pairs when encoding but will only decode documents to lists. This has the side-effect that it's impossible to discern empty arrays from empty documents. Additionally the driver will accept both atoms and strings for document keys but will only decode to strings.

** BSON symbols can only be decoded.

## Usage

### Installation:

Add dynamodb to your mix.exs `:deps` and `:applications` (replace `>= 0.0.0` in `:deps` if you want a specific version). If you want to use poolboy as adapter also add it to your mix.exs `:deps` and `:applications` (because poolboy is an optional dep in dynamodb):

```elixir
  def application do
    [
      applications:
      [
       # ... other deps
       :dynamodb,
       :poolboy # only needed if you want to use poolboy as adapter
      ]
    ]
  end

  defp deps do
    [
      # ... other deps
      {:dynamodb, ">= 0.0.0"},
      {:poolboy, ">= 0.0.0"} # only needed if you want to use poolboy as adapter
    ]
  end
```

Then run ```mix deps.get```.

### Connection Pools

```elixir
defmodule DynamoPool do
  use Dynamo.Pool, name: __MODULE__, adapter: Dynamo.Pool.Poolboy
end

# Starts the pool named DynamoPool
{:ok, _} = DynamoPool.start_link(database: "test")

# Gets an enumerable cursor for the results
cursor = Dynamo.find(DynamoPool, "test-collection", %{})

Enum.to_list(cursor)
|> IO.inspect
```

### Examples
```elixir
Dynamo.find(DynamoPool, "test-collection", %{}, limit: 20)
Dynamo.find(DynamoPool, "test-collection", %{"field" => %{"$gt" => 0}}, limit: 20, sort: %{"field" => 1})

Dynamo.insert_one(DynamoPool, "test-collection", %{"field" => 10})

Dynamo.insert_many(DynamoPool, "test-collection", [%{"field" => 10}, %{"field" => 20}])

Dynamo.delete_one(DynamoPool, "test-collection", %{"field" => 10})

Dynamo.delete_many(DynamoPool, "test-collection", %{"field" => 10})
```

## License

Copyright 2015 Eric Meadows-Jönsson, 2016 Brian Glusman

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

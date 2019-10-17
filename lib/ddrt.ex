defmodule DDRT do
  @moduledoc """
  This is the top level module, which one you should include at your application supervision tree.


  If you want the distributed dynamic r-tree, start this process is a MUST.
      DDRT.start_link(%{})
    or
      children = [
        ...
        {DDRT, %{}}
      ]

  Else, if you want just the dynamic r-tree this module is not a MUST, but you can use it anyways.

  ## Configuration

  Let's talk about which parameters you can pass to init the DDRT.

    `name`: the name of the r-tree.

    `mode`: the mode of the r-tree. There are two:

    - `:dynamic`: all the r-trees with same name in different nodes will be sync.

    - `:standalone`: a dynamic r-tree that just will be at your node.

  `width`: the max width (the number of childs) than can handle every node.

  `type`: the type of data structure that maintains the r-tree. There are two:

    - `Map`: faster way. Recommended if you don't need sync.

    - `MerkleMap`: a bit slower, but perfect to get minimum r-tree modifications.

  `verbose`: allows `Logger` to report console logs. (Decrease performance)

  `seed`: the start seed for the middle nodes uniq ID of the r-tree. Same seed will always reach same sequence of uniq ID's.

  ## Distributed part

  You have to config the Erlang node interconnection with `libcluster`.

  The easy way is that:
    - At `config.exs` define the nodes you want to connect:

          use Mix.Config
          config :libcluster,
          topologies: [
           example: [
             # The selected clustering strategy. Required.
             strategy: Cluster.Strategy.Epmd,
             # Configuration for the provided strategy. Optional.
             config: [hosts: [:"a@localhost", :"b@localhost"]],
           ]
          ]

    - Then you should start you application for example like that:

            eduardo@elixir_rtree $ iex --name a -S mix
            iex(a@localhost)1>

            eduardo@elixir_rtree $ iex --name b -S mix
            iex(b@localhost)1>

  Finally, if you started in both nodes a `DDRT` with the same name you can simply use the `Drtree` API module and you will have the r-tree sync between nodes.

  `Note`: is important that you have the same configuration for the DDRT at the different nodes.

  """

  @doc """
  DDRT party begins.

  ## Examples
    `Note`: if you select mode distributed I'll force you anyways to use MerkleMap.

      iex> DDRT.start_link(%{mode: :distributed, name: Rupert, type: MerkleMap, seed: 5})
      {:ok, #PID<0.224.0>}


  ## Default values
  This would be the default value of every parameters if you omit someone.
      %{
        name: Drtree
        width: 6,
        type: Map,
        mode: :standalone,
        verbose: false,
        seed: 0
      }
  """
  @spec start_link(%{})::{:ok,pid}
  def start_link(opts) do
    name = if opts[:name], do: opts[:name], else: Drtree
    children =
      if opts[:mode] == :distributed do
        [
          {Cluster.Supervisor, [Application.get_env(:libcluster,:topologies), [name: Module.concat([name,ClusterSupervisor])]]},
          {DeltaCrdt, [crdt: DeltaCrdt.AWLWWMap, name: Module.concat([name,Crdt]), on_diffs: &on_diffs(&1,Drtree,name)]},
          {Drtree, [conf: opts, crdt: Module.concat([name,Crdt]), name: name]}
        ]
        else
        [ {Drtree, [conf: opts, name: name]} ]
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: Module.concat([name,Supervisor]))
  end

  @doc false
  def on_diffs(diffs,mod,name) do
    mod.merge_diffs(diffs,name)
  end
end
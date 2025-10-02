defmodule MixUnused.DynamicCallsTest do
  use ExUnit.Case, async: true

  alias MixUnused.DynamicCalls

  describe "find_dynamic_dispatchers/1" do
    test "detects apply/3 calls" do
      tracer_data = %{
        MyModule => [
          {{Kernel, :apply, 3}, %{}},
          {{String, :upcase, 1}, %{}}
        ]
      }

      result = DynamicCalls.find_dynamic_dispatchers(tracer_data)

      assert result == %{MyModule => [{:apply, 3}]}
    end

    test "detects apply/2 calls" do
      tracer_data = %{
        MyModule => [
          {{:erlang, :apply, 2}, %{}}
        ]
      }

      result = DynamicCalls.find_dynamic_dispatchers(tracer_data)

      assert result == %{MyModule => [{:apply, 2}]}
    end

    test "detects unqualified apply calls" do
      tracer_data = %{
        MyModule => [
          {{nil, :apply, 3}, %{}}
        ]
      }

      result = DynamicCalls.find_dynamic_dispatchers(tracer_data)

      assert result == %{MyModule => [{:apply, 3}]}
    end

    test "ignores non-apply calls" do
      tracer_data = %{
        MyModule => [
          {{String, :upcase, 1}, %{}},
          {{Enum, :map, 2}, %{}}
        ]
      }

      result = DynamicCalls.find_dynamic_dispatchers(tracer_data)

      assert result == %{}
    end

    test "groups multiple apply calls from same module" do
      tracer_data = %{
        MyModule => [
          {{Kernel, :apply, 3}, %{}},
          {{Kernel, :apply, 2}, %{}},
          {{:erlang, :apply, 3}, %{}}
        ]
      }

      result = DynamicCalls.find_dynamic_dispatchers(tracer_data)

      assert result == %{MyModule => [{:apply, 3}, {:apply, 2}, {:apply, 3}]}
    end
  end

  describe "apply_call?/3" do
    test "recognizes Kernel.apply/3" do
      assert DynamicCalls.apply_call?(Kernel, :apply, 3)
    end

    test "recognizes Kernel.apply/2" do
      assert DynamicCalls.apply_call?(Kernel, :apply, 2)
    end

    test "recognizes :erlang.apply/3" do
      assert DynamicCalls.apply_call?(:erlang, :apply, 3)
    end

    test "recognizes :erlang.apply/2" do
      assert DynamicCalls.apply_call?(:erlang, :apply, 2)
    end

    test "recognizes unqualified apply/3" do
      assert DynamicCalls.apply_call?(nil, :apply, 3)
    end

    test "recognizes unqualified apply/2" do
      assert DynamicCalls.apply_call?(nil, :apply, 2)
    end

    test "rejects apply with wrong arity" do
      refute DynamicCalls.apply_call?(Kernel, :apply, 1)
      refute DynamicCalls.apply_call?(Kernel, :apply, 4)
    end

    test "rejects non-apply functions" do
      refute DynamicCalls.apply_call?(String, :upcase, 1)
      refute DynamicCalls.apply_call?(Enum, :map, 2)
    end
  end

  describe "generate_warnings/1" do
    test "generates warning for module with apply calls" do
      dynamic_dispatchers = %{
        MyApp.Worker => [{:apply, 3}, {:apply, 2}]
      }

      [warning] = DynamicCalls.generate_warnings(dynamic_dispatchers)

      assert warning =~ "MyApp.Worker"
      assert warning =~ "dynamic dispatch"
      assert warning =~ "apply/2 calls"
      assert warning =~ "incorrectly marked as unused"
    end

    test "generates multiple warnings for multiple modules" do
      dynamic_dispatchers = %{
        MyApp.Worker => [{:apply, 3}],
        MyApp.Service => [{:apply, 2}]
      }

      warnings = DynamicCalls.generate_warnings(dynamic_dispatchers)

      assert length(warnings) == 2
      assert Enum.any?(warnings, &(&1 =~ "MyApp.Worker"))
      assert Enum.any?(warnings, &(&1 =~ "MyApp.Service"))
    end
  end

  describe "suggest_ignore_pattern/1" do
    test "generates ignore pattern suggestion" do
      suggestion = DynamicCalls.suggest_ignore_pattern(MyApp.DynamicModule)

      assert suggestion =~ "mix.exs"
      assert suggestion =~ "unused:"
      assert suggestion =~ "ignore:"
      assert suggestion =~ "{MyApp.DynamicModule, :_, :_}"
      assert suggestion =~ "Module uses dynamic dispatch"
    end
  end
end

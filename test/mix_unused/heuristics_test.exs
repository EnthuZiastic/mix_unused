defmodule MixUnused.HeuristicsTest do
  use ExUnit.Case, async: true

  alias MixUnused.Heuristics
  alias MixUnused.Meta

  describe "likely_export?/2" do
    test "recognizes explicit export annotation" do
      meta = %Meta{doc_meta: %{export: true}}
      assert Heuristics.likely_export?({Foo, :bar, 1}, meta)
    end

    test "recognizes public documentation" do
      meta = %Meta{doc_meta: %{doc: "Public function"}}
      assert Heuristics.likely_export?({Foo, :bar, 1}, meta)
    end

    test "excludes hidden documentation" do
      meta = %Meta{doc_meta: %{doc: :hidden}}
      refute Heuristics.likely_export?({Foo.Internal.Bar, :baz, 1}, meta)
    end

    test "excludes false documentation" do
      meta = %Meta{doc_meta: %{doc: false}}
      refute Heuristics.likely_export?({Foo.Internal.Bar, :baz, 1}, meta)
    end
  end

  describe "is_otp_callback?/2" do
    test "recognizes GenServer callbacks" do
      assert Heuristics.is_otp_callback?(:init, 1)
      assert Heuristics.is_otp_callback?(:handle_call, 3)
      assert Heuristics.is_otp_callback?(:handle_cast, 2)
      assert Heuristics.is_otp_callback?(:handle_info, 2)
      assert Heuristics.is_otp_callback?(:terminate, 2)
    end

    test "recognizes Supervisor callbacks" do
      assert Heuristics.is_otp_callback?(:start_link, 1)
      assert Heuristics.is_otp_callback?(:child_spec, 1)
    end

    test "recognizes Application callbacks" do
      assert Heuristics.is_otp_callback?(:start, 2)
      assert Heuristics.is_otp_callback?(:stop, 1)
    end

    test "rejects non-callbacks" do
      refute Heuristics.is_otp_callback?(:foo, 1)
      refute Heuristics.is_otp_callback?(:bar, 2)
    end
  end

  describe "is_phoenix_callback?/3" do
    test "recognizes Phoenix Controller actions" do
      assert Heuristics.is_phoenix_callback?(MyApp.UserController, :index, 2)
      assert Heuristics.is_phoenix_callback?(MyApp.UserController, :show, 2)
      assert Heuristics.is_phoenix_callback?(MyApp.UserController, :create, 2)
    end

    test "recognizes Phoenix LiveView callbacks" do
      assert Heuristics.is_phoenix_callback?(MyApp.UserLive, :mount, 3)
      assert Heuristics.is_phoenix_callback?(MyApp.UserLive, :render, 1)
      assert Heuristics.is_phoenix_callback?(MyApp.UserLive, :handle_event, 3)
    end

    test "recognizes Phoenix Channel callbacks" do
      assert Heuristics.is_phoenix_callback?(MyApp.UserChannel, :join, 3)
      assert Heuristics.is_phoenix_callback?(MyApp.UserChannel, :handle_in, 3)
    end

    test "recognizes Phoenix View functions" do
      assert Heuristics.is_phoenix_callback?(MyApp.UserView, :render, 2)
      assert Heuristics.is_phoenix_callback?(MyApp.UserView, :any_function, 1)
    end

    test "rejects non-Phoenix modules" do
      refute Heuristics.is_phoenix_callback?(MyApp.Service, :process, 2)
    end
  end

  describe "is_plug_callback?/2" do
    test "recognizes Plug callbacks" do
      assert Heuristics.is_plug_callback?(:init, 1)
      assert Heuristics.is_plug_callback?(:call, 2)
    end

    test "rejects non-Plug functions" do
      refute Heuristics.is_plug_callback?(:process, 2)
    end
  end

  describe "is_ecto_callback?/2" do
    test "recognizes Ecto.Schema callbacks" do
      assert Heuristics.is_ecto_callback?(:changeset, 2)
      assert Heuristics.is_ecto_callback?(:changeset, 3)
      assert Heuristics.is_ecto_callback?(:__schema__, 1)
    end

    test "recognizes Ecto.Type callbacks" do
      assert Heuristics.is_ecto_callback?(:type, 0)
      assert Heuristics.is_ecto_callback?(:cast, 1)
      assert Heuristics.is_ecto_callback?(:load, 1)
      assert Heuristics.is_ecto_callback?(:dump, 1)
    end

    test "rejects non-Ecto functions" do
      refute Heuristics.is_ecto_callback?(:process, 1)
    end
  end

  describe "is_protocol_implementation?/1" do
    test "recognizes known protocol implementations" do
      # Stdlib protocols are recognized by name
      assert Heuristics.is_protocol_implementation?(Enumerable.List)
      assert Heuristics.is_protocol_implementation?(Inspect.Atom)
      # Note: MyProtocol.MyType will NOT be recognized unless it follows the pattern
      # with proper capitalization and isn't a test fixture name
    end

    test "rejects regular modules and test fixtures" do
      refute Heuristics.is_protocol_implementation?(MyApp.Service)
      refute Heuristics.is_protocol_implementation?(MyApp)
      refute Heuristics.is_protocol_implementation?(Foo.Bar)  # Test fixture pattern
      # String.Chars.Integer has 4 parts, not handled by this heuristic
      refute Heuristics.is_protocol_implementation?(String.Chars.Integer)
    end
  end

  describe "is_test_helper?/1" do
    test "recognizes test helper modules" do
      assert Heuristics.is_test_helper?(MyApp.Factory)
      assert Heuristics.is_test_helper?(MyApp.Fixtures)
      assert Heuristics.is_test_helper?(MyApp.TestHelper)
      assert Heuristics.is_test_helper?(MyApp.DataCase)
      assert Heuristics.is_test_helper?(MyApp.ConnCase)
    end

    test "rejects regular modules" do
      refute Heuristics.is_test_helper?(MyApp.Service)
    end
  end

  describe "is_internal_module?/1" do
    test "recognizes internal module patterns" do
      assert Heuristics.is_internal_module?(MyApp.Internal.Service)
      assert Heuristics.is_internal_module?(MyApp.Private.Helper)
      assert Heuristics.is_internal_module?(MyApp.Helpers.Util)
      assert Heuristics.is_internal_module?(MyApp.Internal)
    end

    test "rejects public modules" do
      refute Heuristics.is_internal_module?(MyApp.API)
      refute Heuristics.is_internal_module?(MyApp.Service)
    end
  end
end

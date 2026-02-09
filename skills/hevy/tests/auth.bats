#!/usr/bin/env bats
# Hevy CLI - Authentication Tests

setup() {
  load 'test_helper'
  setup_test_env
}

teardown() {
  cleanup_resources
}

# ============================================================================
# Auth Status Tests
# ============================================================================

@test "hevy auth shows status when authenticated" {
  run_hevy auth

  assert_success
  assert_output_contains "Authenticated"
  assert_output_contains "API key:"
}

@test "hevy auth test validates current API key" {
  run_hevy auth test

  assert_success
  assert_output_contains "API key is valid"
  assert_output_contains "Exercise pages available:"
}

@test "hevy auth --help shows usage" {
  run_hevy auth --help

  assert_success
  assert_output_contains "hevy auth"
  assert_output_contains "Manage API authentication"
}

#!/usr/bin/env bats

load "helpers/common.bash"

setup() {
  REPO_ROOT="$(repo_root)"
}

assert_contains_fixed() {
  local file="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$file"
}

assert_output_contains() {
  [[ "$output" == *"$1"* ]]
}

assert_output_not_contains() {
  [[ "$output" != *"$1"* ]]
}

run_repo_bash() {
  local script="$1"
  run env REPO_ROOT="$REPO_ROOT" bash -lc "$script"
}

@test "git-acp.post-push defines run_post_push_flow as reusable entrypoint" {
  assert_contains_fixed "$REPO_ROOT/lib/ci-workflow.sh" 'run_post_push_flow() {'
}

@test "git-acp.post-push callers converge on run_post_push_flow" {
  assert_contains_fixed \
    "$REPO_ROOT/bin/git-acp.sh" \
    'POST_PUSH_FLOW=true run_post_push_flow "$current_branch" "$base_branch"'
  assert_contains_fixed \
    "$REPO_ROOT/bin/git-ci.sh" \
    'run_post_push_flow "$CURRENT_BRANCH" "$BASE_BRANCH"'
  assert_contains_fixed \
    "$REPO_ROOT/bin/git-promote.sh" \
    'POST_PUSH_FLOW=true run_post_push_flow "${DEVTOOLS_PROMOTE_FROM_BRANCH:-}" "local"'
}

@test "run_post_push_flow returns success when POST_PUSH_FLOW is disabled" {
  run_repo_bash '
    cd "$REPO_ROOT"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/ci-workflow.sh"

    POST_PUSH_FLOW=false
    is_tty() { return 0; }
    detect_ci_tools() { echo DETECT; }
    ci_render_validation_menu_header() { echo HEADER; }
    ci_build_validation_menu() { echo BUILD; }
    ci_prompt_validation_menu() { echo PROMPT >&2; echo help; }
    ci_run_validation_option() { echo DISPATCH; return 42; }

    run_post_push_flow feature/demo dev
    printf "RC:%s\n" "$?"
  '

  [ "$status" -eq 0 ]
  assert_output_contains "RC:0"
  assert_output_not_contains "DETECT"
  assert_output_not_contains "PROMPT"
  assert_output_not_contains "DISPATCH"
}

@test "run_post_push_flow returns success in noninteractive CI-style contexts" {
  run_repo_bash '
    cd "$REPO_ROOT"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/ci-workflow.sh"

    is_tty() { return 0; }
    detect_ci_tools() { echo DETECT; }
    ci_render_validation_menu_header() { echo HEADER; }
    ci_build_validation_menu() { echo BUILD; }
    ci_prompt_validation_menu() { echo PROMPT >&2; echo help; }
    ci_run_validation_option() { echo DISPATCH; return 42; }

    for mode in devtools ci gha; do
      unset DEVTOOLS_NONINTERACTIVE CI GITHUB_ACTIONS
      POST_PUSH_FLOW=true
      case "$mode" in
        devtools) DEVTOOLS_NONINTERACTIVE=1 ;;
        ci) CI=true ;;
        gha) GITHUB_ACTIONS=true ;;
      esac
      run_post_push_flow feature/demo dev
      printf "%s:%s\n" "$mode" "$?"
    done
  '

  [ "$status" -eq 0 ]
  assert_output_contains "devtools:0"
  assert_output_contains "ci:0"
  assert_output_contains "gha:0"
  assert_output_not_contains "PROMPT"
  assert_output_not_contains "DISPATCH"
}

@test "run_post_push_flow returns success without TTY" {
  run_repo_bash '
    cd "$REPO_ROOT"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/ci-workflow.sh"

    unset DEVTOOLS_NONINTERACTIVE CI GITHUB_ACTIONS
    POST_PUSH_FLOW=true
    is_tty() { return 1; }
    detect_ci_tools() { echo DETECT; }
    ci_render_validation_menu_header() { echo HEADER; }
    ci_build_validation_menu() { echo BUILD; }
    ci_prompt_validation_menu() { echo PROMPT >&2; echo help; }
    ci_run_validation_option() { echo DISPATCH; return 42; }

    run_post_push_flow feature/demo dev
    printf "RC:%s\n" "$?"
  '

  [ "$status" -eq 0 ]
  assert_output_contains "RC:0"
  assert_output_not_contains "PROMPT"
  assert_output_not_contains "DISPATCH"
}

@test "run_post_push_flow returns success on protected branches" {
  run_repo_bash '
    cd "$REPO_ROOT"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/ci-workflow.sh"

    unset DEVTOOLS_NONINTERACTIVE CI GITHUB_ACTIONS
    POST_PUSH_FLOW=true
    is_tty() { return 0; }
    detect_ci_tools() { echo DETECT; }
    ci_render_validation_menu_header() { echo HEADER; }
    ci_build_validation_menu() { echo BUILD; }
    ci_prompt_validation_menu() { echo PROMPT >&2; echo help; }
    ci_run_validation_option() { echo DISPATCH; return 42; }

    for branch in dev staging main; do
      run_post_push_flow "$branch" dev
      printf "%s:%s\n" "$branch" "$?"
    done
  '

  [ "$status" -eq 0 ]
  assert_output_contains "dev:0"
  assert_output_contains "staging:0"
  assert_output_contains "main:0"
  assert_output_not_contains "PROMPT"
  assert_output_not_contains "DISPATCH"
}

@test "ci_build_validation_menu always exposes help pr and skip" {
  run_repo_bash '
    cd "$REPO_ROOT"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/ci-workflow.sh"

    ACT_CI_CMD=""
    COMPOSE_CI_CMD=""
    K8S_HEADLESS_CMD=""
    K8S_FULL_CMD=""
    ci_get_native_cmd() { echo ""; }
    detect_minikube_active() { return 0; }
    task_exists() { return 1; }

    has_choice() {
      local needle="$1"
      shift
      local item
      for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
      done
      return 1
    }

    ci_build_validation_menu
    has_choice "$CI_OPT_HELP" "${CI_MENU_CHOICES[@]}" && echo HAS_HELP=1 || echo HAS_HELP=0
    has_choice "$CI_OPT_PR" "${CI_MENU_CHOICES[@]}" && echo HAS_PR=1 || echo HAS_PR=0
    has_choice "$CI_OPT_SKIP" "${CI_MENU_CHOICES[@]}" && echo HAS_SKIP=1 || echo HAS_SKIP=0
  '

  [ "$status" -eq 0 ]
  assert_output_contains "HAS_HELP=1"
  assert_output_contains "HAS_PR=1"
  assert_output_contains "HAS_SKIP=1"
}

@test "ci_map_validation_option keeps canonical mapping for help pr and skip" {
  run_repo_bash '
    cd "$REPO_ROOT"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/ci-workflow.sh"

    ci_build_validation_menu
    printf "HELP:%s\n" "$(ci_map_validation_option "$CI_OPT_HELP")"
    printf "PR:%s\n" "$(ci_map_validation_option "$CI_OPT_PR")"
    printf "SKIP:%s\n" "$(ci_map_validation_option "$CI_OPT_SKIP")"
  '

  [ "$status" -eq 0 ]
  assert_output_contains "HELP:help"
  assert_output_contains "PR:pr"
  assert_output_contains "SKIP:skip"
}

@test "ci_run_validation_option returns control code 11 for help" {
  run_repo_bash '
    cd "$REPO_ROOT"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/ci-workflow.sh"

    have_gum_ui() { return 1; }
    ci_get_native_cmd() { echo ""; }
    ci_resolve_native_app_ci_cmd() { return 0; }
    ci_acp_native_include_devtools_checks() { return 1; }
    ci_build_validation_menu

    ci_run_validation_option "$CI_OPT_HELP" feature/demo dev post
    printf "RC:%s\n" "$?"
  '

  [ "$status" -eq 0 ]
  assert_output_contains "RC:11"
}

@test "ci_run_validation_option returns control code 10 for skip" {
  run_repo_bash '
    cd "$REPO_ROOT"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/ci-workflow.sh"

    ci_get_native_cmd() { echo ""; }
    ci_resolve_native_app_ci_cmd() { return 0; }
    ci_acp_native_include_devtools_checks() { return 1; }
    ci_build_validation_menu

    ci_run_validation_option "$CI_OPT_SKIP" feature/demo dev post
    printf "RC:%s\n" "$?"
  '

  [ "$status" -eq 0 ]
  assert_output_contains "RC:10"
}

@test "run_post_push_flow normalizes rc 10 to visible success" {
  run_repo_bash '
    cd "$REPO_ROOT"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/ci-workflow.sh"

    POST_PUSH_FLOW=true
    unset DEVTOOLS_NONINTERACTIVE CI GITHUB_ACTIONS
    is_tty() { return 0; }
    detect_ci_tools() { :; }
    ci_render_validation_menu_header() { :; }
    ci_build_validation_menu() {
      CI_OPT_HELP="help"
      CI_OPT_PR="pr"
      CI_OPT_SKIP="skip"
      CI_MENU_CHOICES=("$CI_OPT_HELP" "$CI_OPT_PR" "$CI_OPT_SKIP")
    }
    ci_prompt_validation_menu() { echo help; }
    ci_print_task_context_evidence() { :; }
    ci_get_native_cmd() { echo ""; }
    ci_acp_native_include_devtools_checks() { return 1; }
    ci_resolve_native_app_ci_cmd() { return 0; }
    ci_is_skip_option() { return 1; }
    ci_run_validation_option() { return 10; }

    run_post_push_flow feature/demo dev
    printf "RC:%s\n" "$?"
  '

  [ "$status" -eq 0 ]
  assert_output_contains "RC:0"
}

@test "run_post_push_flow reaches prompt and dispatch and normalizes rc 11 to success" {
  run_repo_bash '
    cd "$REPO_ROOT"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/ci-workflow.sh"

    POST_PUSH_FLOW=true
    unset DEVTOOLS_NONINTERACTIVE CI GITHUB_ACTIONS
    is_tty() { return 0; }
    detect_ci_tools() { echo DETECT; }
    ci_render_validation_menu_header() { echo HEADER:$1; }
    ci_build_validation_menu() {
      echo BUILD
      CI_OPT_HELP="help"
      CI_OPT_PR="pr"
      CI_OPT_SKIP="skip"
      CI_MENU_CHOICES=("$CI_OPT_HELP" "$CI_OPT_PR" "$CI_OPT_SKIP")
    }
    ci_prompt_validation_menu() {
      echo PROMPT >&2
      echo help
    }
    ci_print_task_context_evidence() { :; }
    ci_get_native_cmd() { echo ""; }
    ci_acp_native_include_devtools_checks() { return 1; }
    ci_resolve_native_app_ci_cmd() { return 0; }
    ci_is_skip_option() { return 1; }
    ci_run_validation_option() {
      echo DISPATCH:$1:$2:$3:$4
      return 11
    }

    run_post_push_flow feature/demo dev
    printf "RC:%s\n" "$?"
  '

  [ "$status" -eq 0 ]
  assert_output_contains "DETECT"
  assert_output_contains "HEADER:feature/demo"
  assert_output_contains "BUILD"
  assert_output_contains "PROMPT"
  assert_output_contains "DISPATCH:help:feature/demo:dev:post"
  assert_output_contains "RC:0"
}

@test "run_post_push_flow propagates non control rc" {
  run_repo_bash '
    cd "$REPO_ROOT"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/ci-workflow.sh"

    POST_PUSH_FLOW=true
    unset DEVTOOLS_NONINTERACTIVE CI GITHUB_ACTIONS
    is_tty() { return 0; }
    detect_ci_tools() { :; }
    ci_render_validation_menu_header() { :; }
    ci_build_validation_menu() {
      CI_OPT_HELP="help"
      CI_OPT_PR="pr"
      CI_OPT_SKIP="skip"
      CI_MENU_CHOICES=("$CI_OPT_HELP" "$CI_OPT_PR" "$CI_OPT_SKIP")
    }
    ci_prompt_validation_menu() { echo help; }
    ci_print_task_context_evidence() { :; }
    ci_get_native_cmd() { echo ""; }
    ci_acp_native_include_devtools_checks() { return 1; }
    ci_resolve_native_app_ci_cmd() { return 0; }
    ci_is_skip_option() { return 1; }
    ci_run_validation_option() { return 42; }

    run_post_push_flow feature/demo dev
    printf "RC:%s\n" "$?"
  '

  [ "$status" -eq 0 ]
  assert_output_contains "RC:42"
}

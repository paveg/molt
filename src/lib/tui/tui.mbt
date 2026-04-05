///|
pub struct TuiState {
  url : String
  connections : Int
  duration_ms : Int
  mut total_requests : Int
  mut successful : Int
  mut failed : Int
  mut current_rps : Int
  mut elapsed_ms : Double
  mut p50_us : Int64
  mut p99_us : Int64
}

///|
pub fn TuiState::new(
  url : String,
  connections : Int,
  duration_ms : Int,
) -> TuiState {
  {
    url,
    connections,
    duration_ms,
    total_requests: 0,
    successful: 0,
    failed: 0,
    current_rps: 0,
    elapsed_ms: 0.0,
    p50_us: 0L,
    p99_us: 0L,
  }
}

///|
pub fn TuiState::update(
  self : TuiState,
  total_requests~ : Int,
  successful~ : Int,
  failed~ : Int,
  elapsed_ms~ : Double,
  p50_us~ : Int64,
  p99_us~ : Int64,
) -> Unit {
  self.total_requests = total_requests
  self.successful = successful
  self.failed = failed
  self.elapsed_ms = elapsed_ms
  self.p50_us = p50_us
  self.p99_us = p99_us
  self.current_rps = if elapsed_ms > 0.0 {
    (total_requests.to_double() / (elapsed_ms / 1000.0)).to_int()
  } else {
    0
  }
}

///|
pub fn TuiState::progress_ratio(self : TuiState) -> Double {
  guard self.duration_ms > 0 else { return 0.0 }
  let ratio = self.elapsed_ms / self.duration_ms.to_double()
  if ratio > 1.0 {
    1.0
  } else {
    ratio
  }
}

///|
fn format_latency_display(us : Int64) -> String {
  let ms_whole = us / 1000L
  let ms_frac = us % 1000L / 10L
  let frac_str = if ms_frac < 10L { "0\{ms_frac}" } else { "\{ms_frac}" }
  "\{ms_whole}.\{frac_str}ms"
}

///|
fn format_elapsed_display(ms : Double) -> String {
  let sec_whole = (ms / 1000.0).to_int()
  let sec_frac = (ms % 1000.0 / 100.0).to_int()
  "\{sec_whole}.\{sec_frac}s"
}

///|
pub fn render_tui_node(state : TuiState) -> @vnode.TuiNode {
  let progress = state.progress_ratio()
  let elapsed_str = format_elapsed_display(state.elapsed_ms)
  let remaining_ms = state.duration_ms.to_double() - state.elapsed_ms
  let remaining_str = if remaining_ms > 0.0 {
    format_elapsed_display(remaining_ms)
  } else {
    "0.0s"
  }
  @vnode.column([
    // Header
    @vnode.text("molt v0.1.0 -- MoonBit HTTP Load Tester", bold=true, fg="cyan"),
    @vnode.text(""),
    // Target info
    @components.stat("Target", state.url, label_width=12),
    @components.stat(
      "Connections",
      state.connections.to_string(),
      label_width=12,
    ),
    @vnode.text(""),
    // Progress bar
    @vnode.row([
      @vnode.text("  [\{elapsed_str} / \{remaining_str}]  ", fg="gray"),
      @components.progress_bar(progress, width=40),
    ]),
    @vnode.text(""),
    // Live stats
    @vnode.row([
      @components.stat(
        "Requests",
        state.total_requests.to_string(),
        label_width=12,
      ),
      @components.stat("RPS", state.current_rps.to_string(), label_width=8),
    ]),
    @vnode.row([
      @components.stat("Success", state.successful.to_string(), label_width=12),
      @components.stat("Failed", state.failed.to_string(), label_width=8),
    ]),
    @vnode.text(""),
    // Latency
    @vnode.row([
      @components.stat(
        "p50",
        format_latency_display(state.p50_us),
        label_width=12,
      ),
      @components.stat(
        "p99",
        format_latency_display(state.p99_us),
        label_width=8,
      ),
    ]),
  ])
}

///|
pub fn render_tui_to_string(
  state : TuiState,
  width : Int,
  height : Int,
) -> String {
  let node = render_tui_node(state)
  @vnode.render_vnode_once(width, height, node)
}

///|
/// Plain text one-line summary for --no-tui mode (1 per second)
pub fn format_plain_status(state : TuiState) -> String {
  let elapsed = format_elapsed_display(state.elapsed_ms)
  let p50 = format_latency_display(state.p50_us)
  let p99 = format_latency_display(state.p99_us)
  "[\{elapsed}] \{state.total_requests} requests | \{state.current_rps} req/s | p50: \{p50} | p99: \{p99} | errors: \{state.failed}"
}

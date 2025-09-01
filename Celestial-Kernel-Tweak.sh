#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
# This will make sure your module will still work
# if Magisk change its mount point in the future.
#
# Thanks and credits to tytydraco, notzeetaa, and all developers 
# for providing references and inspiration in building this kernel module.
#
# Additional improvements, edits, and optimization by Kazuyoo
# with the goal of better performance, stability, and efficiency.
# Detect if we are running on Android
  grep -q android /proc/cmdline && ANDROID=true
  
# ----------------- OPTIMIZATION CPU SECTIONS -----------------
# Loop over each CPU in the system (@tytydraco (ghitub)) edited by @Kzuyoo
  for cpu_path in /sys/devices/system/cpu/cpu[0-7]/cpufreq; do
    avail_govs="$(cat "$cpu_path/scaling_available_governors")"
    cpu_name=$(basename "$(dirname "$cpu_path")")

    if [[ "$cpu_name" == cpu[0-3] ]]; then
      # Little core → more economical
      for gov in schedutil schedplus interactive; do
        if [[ "$avail_govs" == *"$gov"* ]]; then
          write_value "$cpu_path/scaling_governor" "$gov"
          break
        fi
      done
    else
      # Big core → stable
      for gov in performance schedplus schedutil interactive; do
        if [[ "$avail_govs" == *"$gov"* ]]; then
          write_value "$cpu_path/scaling_governor" "$gov"
          break
        fi
      done
    fi
  done

# CPU Governor settings (LITTLE: cpu0-3, big: cpu4-7)
# thx @Bias_khaliq, edited & optimized by @Kzuyoo
  for cpu_path in /sys/devices/system/cpu/cpu[0-7]/cpufreq; do
    # Helper: calculate mid frequency
    calculate_mid_freq() {
      local min_freq=$(cat "$1/cpuinfo_min_freq")
      local max_freq=$(cat "$1/cpuinfo_max_freq")
      local mid=$(( (min_freq + max_freq) / 2 ))
      echo $(( (mid / 100000) * 100000 ))
    }

    min_freq=$(cat "$cpu_path/cpuinfo_min_freq")
    max_freq=$(cat "$cpu_path/cpuinfo_max_freq")
    mid_freq=$(calculate_mid_freq "$cpu_path")
    cpu_name=$(basename "$(dirname "$cpu_path")")

    case "$cpu_name" in
      cpu[0-3])
        write_value "$cpu_path/scaling_min_freq" "$min_freq"
        write_value "$cpu_path/scaling_max_freq" "$mid_freq"
        ;;
      cpu[4-7])
        write_value "$cpu_path/scaling_min_freq" "$mid_freq"
        write_value "$cpu_path/scaling_max_freq" "$max_freq"
        ;;
    esac
  done

# -------- OPTIMIZATION KERNEL SECTIONS --------
# Schedule this ratio of tasks in the guarenteed sched period
  write_value "$KERNEL_PATH/sched_min_granularity_ns" "$((SCHED_PERIOD / SCHED_TASKS))"

# Require preeptive tasks to surpass half of a sched period in vmruntime
  write_value "$KERNEL_PATH/sched_wakeup_granularity_ns" "$((SCHED_PERIOD / 3))"
  
# Reduce the maximum scheduling period for lower latency
  write_value "$KERNEL_PATH/sched_latency_ns" "$SCHED_PERIOD"

# Reduce task migration frequency (ns)
  write_value "$KERNEL_PATH/sched_migration_cost_ns" "250000"

# Period for real-time duty cycle (us)
  write_value "$KERNEL_PATH/sched_rt_period_us" "2000000"
  
# Balancing real-time responsiveness and CPU availability (us)
  write_value "$KERNEL_PATH/sched_rt_runtime_us" "950000"
  
# Specifies the time window size (in nanoseconds) for CPU time sharing calculations.
  write_value "$KERNEL_PATH/sched_shares_window_ns" "8000000"
  
# Scheduler boosting allows temporary priority increases for certain threads or processes to gain more CPU time.
  write_value "$KERNEL_PATH/sched_boost" "2000000"
  
# sets the avg (time averaging period) in milliseconds for task load tracking calculation by the scheduler.
  write_value "$KERNEL_PATH/sched_time_avg_ms" "125"
  
# gives an initial value of the task load based on a specified percentage
  write_value "$KERNEL_PATH/sched_walt_init_task_load_pct" "15"

# Upper and lower limits for CPU utility settings
  write_value "$KERNEL_PATH/sched_util_clamp_max" "768"
  write_value "$KERNEL_PATH/sched_util_clamp_min" "96"

# determines the CPU utilization level that triggers task migration to another CPU during high load.
  write_value "$KERNEL_PATH/sched_upmigrate" "75"
  write_value "$KERNEL_PATH/sched_downmigrate" "55"

# Reduce scheduler migration time to improve real-time latency
  write_value "$KERNEL_PATH/sched_nr_migrate" "32"

# Limit max perf event processing time to this much CPU usage
  write_value "$KERNEL_PATH/perf_cpu_time_max_percent" "5"
  
# Enable WALT for CPU utilization
  write_value "$KERNEL_PATH/sched_use_walt_cpu_util" "1"

# Enable WALT for task utilization
  write_value "$KERNEL_PATH/sched_use_walt_task_util" "1"
  
# can improve the isolation of CPU-intensive processes.
  write_value "$KERNEL_PATH/sched_autogroup_enabled" "1"
  
# Execute child process before parent after fork
  write_value "$KERNEL_PATH/sched_child_runs_first" "1"
  
# Initial settings for the next parameter values
  write_value "$KERNEL_PATH/sched_tunable_scaling" "0"

# Disables timer migration from one CPU to another.
  write_value "$KERNEL_PATH/timer_migration" "0"
  
# Disable CFS boost
  write_value "$KERNEL_PATH/sched_cfs_boost" "0"

# Disable isolation hint
  write_value "$KERNEL_PATH/sched_isolation_hint" "0"
  
# Disable Sched Sync Hint
  write_value "$KERNEL_PATH/sched_sync_hint_enable" "0"

# Disable scheduler statistics to reduce overhead
  write_value "$KERNEL_PATH/sched_schedstats" "0"
    
# Always allow sched boosting on top-app tasks
[[ "$ANDROID" == true ]] && write_value "$KERNEL_PATH/sched_min_task_util_for_colocation" "0"

# Disable compatibility logging.
  write_value "$KERNEL_PATH/compat-log" "0"
    
# improves security by preventing users from triggering malicious commands or debugging.
  write_value "$KERNEL_PATH/sysrq" "0"
 
# -------- OPTIMIZATION VM & QUEUE SECTIONS --------
# Specifies the increase in memory reserve on the watermark to avoid running out of memory.
  write_value "$VM_PATH/watermark_boost_factor" "1000"
  
# background daemon writes pending data to disk.
  write_value "$VM_PATH/dirty_writeback_centisecs" "250"
    
# before data that is considered "dirty" must be written to disk.
  write_value "$VM_PATH/dirty_expire_centisecs" "500"
  
# Controlling kernel tendency to use swap
  write_value "$VM_PATH/swappiness" "15"
   
# Determines the percentage of physical RAM that can be allocated to additional virtual memory during overcommit.
  write_value "$VM_PATH/overcommit_ratio" "50"
   
# Specifies the interval (in seconds) for updating kernel virtual memory statistics.
  write_value "$VM_PATH/stat_interval" "30"
  
# Clearing the dentry and inode cache.
  write_value "$VM_PATH/vfs_cache_pressure" "75"

# The maximum percentage of system memory that can be used for "dirty" data before being forced to write_value" "to disk.
  write_value "$VM_PATH/dirty_ratio" "20"
    
# The percentage of memory that triggers "dirty" data writing to disk in the background.
  write_value "$VM_PATH/dirty_background_ratio" "5"
    
# Determines the number of memory pages loaded at once when reading from swap.
  write_value "$VM_PATH/page-cluster" "0"
    
# Controls logging of disk I/O activity.
  write_value "$VM_PATH/block_dump" "0"
    
# Determines whether the kernel prioritizes killing tasks that allocate memory when an OOM (Out of Memory) occurs.
  write_value "$VM_PATH/oom_kill_allocating_task" "0"
    
# Controls whether the kernel records running task information when an OOM occurs.
  write_value "$VM_PATH/oom_dump_tasks" "0"
  
# Set up for I/O thx to (@tytydraco (ghitub)) edited by @Kzuyoo
  for queue in /sys/block/*/queue; do
    avail_scheds="$(cat "$queue/scheduler")"
    for sched in mq-deadline none deadline; do
      if [[ "$avail_scheds" == *"$sched"* ]]; then
        write_value "$queue/scheduler" "$sched"
        break
      fi
  done

	# Do not use I/O as a source of randomness
	 write_value "$queue/add_random" "0"

	# Disable I/O statistics accounting
	 write_value "$queue/iostats" "0"

	# Reduce the maximum number of I/O requests in exchange for latency
	 write_value "$queue/nr_requests" "128"
	
	# Determines the quantum of time (in milliseconds) given to a task in one CPU scheduler cycle. 
	 write_value "$queue/quantum" "16"
	
	# Controls the merging of I/O requests.
     write_value "$queue/nomerges" "2"
    
    # Controls how I/O queues relate to the CPU.
     write_value "$queue/rq_affinity" "2"
    
    # Controls whether the scheduler provides additional idle time for I/O.
     write_value "$queue/iosched/slice_idle" "0"
    
    # Disable additional idle for groups.
     write_value "$queue/group_idle" "0"
    
    # Controls whether entropy from disk operations is added to the kernel randomization pool.
     write_value "$queue/add_random" "0"
    
    # Identifying the device as non-rotational.
     write_value "$queue/rotational" "0"
 done
  
# -------- OPTIMIZATION NET SECTIONS --------
# Disable TCP timestamps for reduced overhead
  write_value "$NET_PATH/ipv4/tcp_timestamps" "0"

# Enable TCP low latency mode
  write_value "$NET_PATH/ipv4/tcp_low_latency" "1"
  
# for TCP speed control — faster & more efficient on modern networks.
  write_value "$NET_PATH/ipv4/tcp_congestion_control" "cubic"
  
# Enable TCP Fast Open — speeds up initial TCP connections, great for online browsing & apps.
  write_value "$NET_PATH/ipv4/tcp_fastopen" "1"
  
# Automatically detects optimal packet size, avoids fragmentation & speeds up connections.
  write_value "$NET_PATH/ipv4/tcp_mtu_probing" "1"
  
# -------- OPTIMIZATION OTHER SETTINGS SECTIONS --------
# Enable Dynamic Fsync
  write_value "$KERNEL2_PATH/dyn_fsync/Dyn_fsync_active" "1"
  
# reduce RAM consumption on low-memory devices (thx to @Bias_Khaliq)
  if [ -d "$KERNEL2_PATH/mm/ksm/" ]; then
    write_value "/sys/kernel/mm/ksm/run" "1"
    write_value "/sys/kernel/mm/ksm/sleep_millisecs" "1000"
  fi
  
# Disable Kernel Panic
  for KERNEL_PANIC in $(find /proc/sys/ /sys/ -name '*panic*'); do
    write_value "$KERNEL_PANIC" "0"
  done
   
# Change kernel mode to HMP Mode
  if [ -d "$CPU_EAS_PATH/" ]; then
    write_value "$CPU_EAS_PATH/enable" "0"
  fi
	
# additional settings in kernel
  if [ -d "$KERNEL2_PATH/ged/hal/" ]; then
    write_value "$KERNEL2_PATH/ged/hal/gpu_boost_level" "2"
  fi

  if [ -d "$KERNEL2_PATH/debug/" ]; then
  # Consider scheduling tasks that are eager to run
	write_value "$KERNEL2_PATH/debug/sched_features" "NEXT_BUDDY"

  # Schedule tasks on their origin CPU if possible
	write_value "$KERNEL2_PATH/debug/sched_features" "TTWU_QUEUE"
  fi
  
# Disable logs & debuggers (thx to @Bias_Khaliq)
  for exception_trace in $(find /proc/sys/ -name exception-trace); do
    write_value "$exception_trace" "0"
  done

  for sched_schedstats in $(find /proc/sys/ -name sched_schedstats); do
    write_value "$sched_schedstats" "0"
  done

  for printk in $(find /proc/sys/ -name printk); do
    write_value "$printk" "0 0 0 0"
  done

  for printk_devkmsg in $(find /proc/sys/ -name printk_devkmsg); do
    write_value "$printk_devkmsg" "off"
  done

  for tracing_on in $(find /proc/sys/ -name tracing_on); do
    write_value "$tracing_on" "0"
  done

  for log_ecn_error in $(find /sys/ -name log_ecn_error); do
    write_value "$log_ecn_error" "0"
  done

  for snapshot_crashdumper in $(find /sys/ -name snapshot_crashdumper); do
    write_value "$snapshot_crashdumper" "0"
  done

# Disable CRC check
  for use_spi_crc in $(find /sys/module -name use_spi_crc); do
    write_value "$use_spi_crc" "0"
  done
     
# cleaning
  write_value "$VM_PATH/drop_caches" "3"
  write_value "$VM_PATH/compact_memory" "1"
     
# Always return success, even if the last write fails
  sync; send_notification; exit 0

# This script will be executed in late_start service mode

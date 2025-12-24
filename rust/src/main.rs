use freeup_ram_rust::{cleanup_memory};
use std::process;

fn main() {
    match cleanup_memory() {
        Ok((before, after, freed_mb)) => {
            // 计算清理前后的整体RAM使用百分比
            let before_percent = (before.used as f64 / before.total as f64) * 100.0;
            let after_percent = (after.used as f64 / after.total as f64) * 100.0;

            if freed_mb > 0.0 {
                // 简洁输出格式：百分比变化和清理量
                println!("{:.0}%->{:.0}%,{:.0}MB off", before_percent, after_percent, freed_mb);
            } else {
                // 如果没有释放内存
                println!("内存状态良好 ({:.0}%使用中)", before_percent);
            }
        }
        Err(e) => {
            eprintln!("内存清理失败: {}", e);
            process::exit(1);
        }
    }
}
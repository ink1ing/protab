//! macOS 内存清理工具 - Rust 实现
//! 基于 BuhoCleaner 算法，确保内存安全

use anyhow::{anyhow, Result};
use std::collections::LinkedList;
use std::ptr;

/// 内存块结构，使用安全的 Rust 内存管理
#[derive(Debug)]
pub struct MemoryBlock {
    ptr: *mut u8,
    size: usize,
}

unsafe impl Send for MemoryBlock {}
unsafe impl Sync for MemoryBlock {}

impl MemoryBlock {
    /// 创建新的内存块，增强安全检查
    pub fn new(size: usize) -> Result<Self> {
        // 输入验证：检查大小限制
        if size == 0 {
            return Err(anyhow!("Memory block size cannot be zero"));
        }

        // 防止过大的内存分配（限制为1GB）
        const MAX_BLOCK_SIZE: usize = 1024 * 1024 * 1024; // 1GB
        if size > MAX_BLOCK_SIZE {
            return Err(anyhow!("Memory block size {} exceeds maximum limit of {} bytes", size, MAX_BLOCK_SIZE));
        }

        unsafe {
            let ptr = libc::mmap(
                ptr::null_mut(),
                size,
                libc::PROT_READ | libc::PROT_WRITE,
                libc::MAP_PRIVATE | libc::MAP_ANON,
                -1,
                0,
            );

            if ptr == libc::MAP_FAILED {
                return Err(anyhow!("Failed to allocate memory block of size {}: mmap failed", size));
            }

            // 验证返回的指针不是NULL
            if ptr.is_null() {
                return Err(anyhow!("mmap returned null pointer"));
            }

            // 安全地填充内存以强制系统分配物理页
            let result = libc::memset(ptr, 0x00, size); // 使用0x00而非0xFF减少系统压力
            if result.is_null() {
                // 如果memset失败，清理已分配的内存
                libc::munmap(ptr as *mut libc::c_void, size);
                return Err(anyhow!("Failed to initialize memory block"));
            }

            Ok(MemoryBlock {
                ptr: ptr as *mut u8,
                size,
            })
        }
    }

    /// 安全写入数据到内存块
    pub fn safe_write(&self, offset: usize, data: u8) -> Result<()> {
        if offset >= self.size {
            return Err(anyhow!("Write offset {} exceeds block size {}", offset, self.size));
        }

        unsafe {
            std::ptr::write_volatile(self.ptr.add(offset), data);
        }
        Ok(())
    }

    /// 安全写入模式数据
    pub fn write_pattern(&self, pattern: u8) -> Result<()> {
        if self.ptr.is_null() {
            return Err(anyhow!("Cannot write to null pointer"));
        }

        unsafe {
            // 分块写入，每16KB检查一次
            const CHUNK_SIZE: usize = 16384; // 16KB
            let mut remaining = self.size;
            let mut offset = 0usize;

            while remaining > 0 {
                let chunk_size = std::cmp::min(CHUNK_SIZE, remaining);

                // 边界检查
                if offset + chunk_size > self.size {
                    return Err(anyhow!("Write would exceed block boundaries"));
                }

                // 安全写入当前块
                for i in (0..chunk_size).step_by(4096) { // 每4KB写一次
                    if offset + i < self.size {
                        std::ptr::write_volatile(self.ptr.add(offset + i), pattern);
                    }
                }

                offset += chunk_size;
                remaining = remaining.saturating_sub(chunk_size);
            }
        }
        Ok(())
    }
}

impl Drop for MemoryBlock {
    /// 安全释放内存，增强错误处理
    fn drop(&mut self) {
        unsafe {
            if !self.ptr.is_null() {
                let result = libc::munmap(self.ptr as *mut libc::c_void, self.size);

                // 记录释放失败，但不panic（因为在析构函数中）
                if result != 0 {
                    eprintln!("Warning: munmap failed for memory block of size {}: errno {}",
                             self.size, *libc::__error());
                }

                // 防止双重释放
                self.ptr = ptr::null_mut();
                self.size = 0;
            }
        }
    }
}

/// 内存信息结构
#[derive(Debug, Clone, Copy)]
pub struct MemoryInfo {
    pub total: u64,
    pub free: u64,
    pub used: u64,
    pub active: u64,
    pub inactive: u64,
    pub wired: u64,
    pub compressed: u64,
    pub purgeable: u64,
    pub speculative: u64,
}

/// 动态获取系统页面大小
pub fn get_page_size() -> Result<u64> {
    let page_size = unsafe { libc::sysconf(libc::_SC_PAGESIZE) };
    
    if page_size <= 0 {
        // 回退到默认值（Apple Silicon 通常使用 16KB）
        eprintln!("Warning: Failed to get page size, using default 16KB");
        return Ok(16384);
    }
    
    Ok(page_size as u64)
}

/// 获取总物理内存
pub fn get_total_memory() -> Result<u64> {
    let mut size = std::mem::size_of::<u64>();
    let mut total_memory: u64 = 0;
    let mut mib = [libc::CTL_HW, libc::HW_MEMSIZE];

    let result = unsafe {
        libc::sysctl(
            mib.as_mut_ptr(),
            2,
            &mut total_memory as *mut _ as *mut libc::c_void,
            &mut size,
            ptr::null_mut(),
            0,
        )
    };

    if result != 0 {
        return Err(anyhow!("Failed to get total memory"));
    }

    Ok(total_memory)
}

/// 获取详细内存信息（使用简化的方式）
pub fn get_memory_info() -> Result<MemoryInfo> {
    let total = get_total_memory()?;

    // 使用简化的内存信息获取方式
    let mut vm_stats: libc::vm_statistics64_data_t = unsafe { std::mem::zeroed() };
    let mut count = libc::HOST_VM_INFO64_COUNT;

    let result = unsafe {
        libc::host_statistics64(
            libc::mach_host_self(),
            libc::HOST_VM_INFO64,
            &mut vm_stats as *mut _ as *mut libc::integer_t,
            &mut count,
        )
    };

    if result != libc::KERN_SUCCESS {
        return Err(anyhow!("Failed to get memory statistics: {}", result));
    }

    // 动态获取系统页面大小
    let page_size = get_page_size()?;

    let active = vm_stats.active_count as u64 * page_size;
    let inactive = vm_stats.inactive_count as u64 * page_size;
    let wired = vm_stats.wire_count as u64 * page_size;
    let compressed = vm_stats.compressor_page_count as u64 * page_size;
    let purgeable = vm_stats.purgeable_count as u64 * page_size;
    let speculative = vm_stats.speculative_count as u64 * page_size;
    let free_count = vm_stats.free_count as u64 * page_size;

    // Match macOS Activity Monitor calculation:
    // Memory Used = App Memory + Wired + Compressed
    // App Memory ≈ Active - Purgeable (memory used by apps)
    // Note: inactive 和 speculative 被视为可回收，不计入 "已使用"
    let app_memory = active.saturating_sub(purgeable);
    let used = app_memory + wired + compressed;
    let free = free_count + inactive + purgeable + speculative;

    Ok(MemoryInfo {
        total,
        free,
        used,
        active,
        inactive,
        wired,
        compressed,
        purgeable,
        speculative,
    })
}

/// 执行内存清理
pub fn cleanup_memory() -> Result<(MemoryInfo, MemoryInfo, f64)> {
    // 获取清理前的内存信息
    let before = get_memory_info()?;

    println!("Cleaning memory...");

    // 1. 多轮 purge 命令预清理
    for _ in 0..3 {
        let _ = std::process::Command::new("purge").output();
        std::thread::sleep(std::time::Duration::from_millis(100));
    }

    // 2. 计算需要清理的内存（超激进策略）
    let target_memory = before.inactive + before.purgeable + before.speculative + before.compressed;

    // 3. 使用温和的内存压力策略，避免触发安全弹窗
    let total_memory = before.total;
    let gentle_target = std::cmp::min(target_memory, total_memory / 8); // 温和策略：最多清理1/8内存

    if gentle_target > 0 {
        // 阶段1：适度的内存分配
        let mut memory_blocks: LinkedList<MemoryBlock> = LinkedList::new();
        let mut allocated = 0u64;
        const MODERATE_BLOCK_SIZE: usize = 16 * 1024 * 1024; // 16MB 适中块

        // 分配目标内存的 120% 来温和地释放缓存
        let pressure_target = std::cmp::min(gentle_target + gentle_target / 5, total_memory / 6);

        while allocated < pressure_target {
            let alloc_size = std::cmp::min(MODERATE_BLOCK_SIZE, (pressure_target - allocated) as usize);

            match MemoryBlock::new(alloc_size) {
                Ok(block) => {
                    allocated += alloc_size as u64;

                    // 使用安全的写入方法
                    if let Err(e) = block.write_pattern(0xAA) {
                        eprintln!("Warning: Failed to write pattern to memory block: {}", e);
                        // 继续处理，不中断清理过程
                    }

                    memory_blocks.push_back(block);
                }
                Err(e) => {
                    eprintln!("Memory allocation failed: {}", e);
                    break; // 内存分配失败，停止
                }
            }

            // 更长的间隔，避免系统过载
            if allocated % (128 * 1024 * 1024) == 0 {
                std::thread::sleep(std::time::Duration::from_millis(100));
            }
        }

        // 4. 保持内存压力适中时间
        std::thread::sleep(std::time::Duration::from_millis(200));

        // 阶段2：温和的内存释放和重分配
        let quarter_count = memory_blocks.len() / 4;
        for _ in 0..quarter_count {
            memory_blocks.pop_back();
        }

        std::thread::sleep(std::time::Duration::from_millis(100));

        // 适量重新分配小块内存
        for i in 0..20 {
            match MemoryBlock::new(8 * 1024 * 1024) { // 8MB 小块
                Ok(block) => {
                    // 安全写入模式
                    if let Err(e) = block.safe_write(0, (allocated + i as u64) as u8) {
                        eprintln!("Warning: Failed to write to memory block: {}", e);
                    }
                    memory_blocks.push_back(block);
                }
                Err(e) => {
                    eprintln!("Failed to allocate small memory block: {}", e);
                }
            }

            // 每5个块暂停
            if i % 5 == 0 {
                std::thread::sleep(std::time::Duration::from_millis(50));
            }
        }

        std::thread::sleep(std::time::Duration::from_millis(150));

        // 5. 释放所有分配的内存（触发RAII）
        drop(memory_blocks);

        // 6. 适度的最终清理
        for i in 0..3 {
            let _ = std::process::Command::new("purge").output();
            if i < 2 {
                std::thread::sleep(std::time::Duration::from_millis(200));
            }
        }
    } else {
        // 非常温和的备用策略
        let mut temp_blocks: LinkedList<MemoryBlock> = LinkedList::new();

        // 分配少量内存块
        for i in 0..10 {
            match MemoryBlock::new(8 * 1024 * 1024) { // 8MB
                Ok(block) => {
                    // 安全写入模式
                    if let Err(e) = block.safe_write(0, i as u8) {
                        eprintln!("Warning: Failed to write to fallback memory block: {}", e);
                    }
                    temp_blocks.push_back(block);
                }
                Err(e) => {
                    eprintln!("Failed to allocate fallback memory block: {}", e);
                }
            }
            std::thread::sleep(std::time::Duration::from_millis(100));
        }

        std::thread::sleep(std::time::Duration::from_millis(200));
        drop(temp_blocks);

        // 温和清理
        for _ in 0..2 {
            let _ = std::process::Command::new("purge").output();
            std::thread::sleep(std::time::Duration::from_millis(300));
        }
    }

    // 等待系统更新内存统计
    std::thread::sleep(std::time::Duration::from_millis(500));

    // 获取清理后的内存信息
    let after = get_memory_info()?;

    // 计算释放的内存量（更准确的计算）
    let freed_bytes = if before.used > after.used {
        before.used - after.used
    } else if after.free > before.free {
        after.free - before.free
    } else {
        // 检查各个内存组件的变化
        let inactive_freed = before.inactive.saturating_sub(after.inactive);
        let purgeable_freed = before.purgeable.saturating_sub(after.purgeable);
        let speculative_freed = before.speculative.saturating_sub(after.speculative);
        let compressed_freed = before.compressed.saturating_sub(after.compressed);

        inactive_freed + purgeable_freed + speculative_freed + compressed_freed
    };

    let freed_mb = freed_bytes as f64 / (1024.0 * 1024.0);

    Ok((before, after, freed_mb))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_total_memory() {
        let total = get_total_memory().unwrap();
        assert!(total > 0);
        println!("Total memory: {} MB", total / 1024 / 1024);
    }

    #[test]
    fn test_get_memory_info() {
        let info = get_memory_info().unwrap();
        assert!(info.total > 0);
        assert!(info.used > 0);
        println!("Memory info: {:?}", info);
    }

    #[test]
    fn test_memory_block_creation() {
        let block = MemoryBlock::new(1024 * 1024).unwrap();
        assert!(!block.ptr.is_null());
        assert_eq!(block.size, 1024 * 1024);
        // 块会在作用域结束时自动释放
    }

    #[test]
    fn test_memory_block_zero_size() {
        let result = MemoryBlock::new(0);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("cannot be zero"));
    }

    #[test]
    fn test_memory_block_oversized() {
        let result = MemoryBlock::new(2 * 1024 * 1024 * 1024); // 2GB
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("exceeds maximum limit"));
    }

    #[test]
    fn test_safe_write() {
        let block = MemoryBlock::new(4096).unwrap();

        // 正常写入应该成功
        assert!(block.safe_write(0, 0xAA).is_ok());
        assert!(block.safe_write(4095, 0xBB).is_ok());

        // 超出边界的写入应该失败
        assert!(block.safe_write(4096, 0xCC).is_err());
    }

    #[test]
    fn test_write_pattern() {
        let block = MemoryBlock::new(64 * 1024).unwrap(); // 64KB

        // 写入模式应该成功
        assert!(block.write_pattern(0x55).is_ok());
    }

    #[test]
    fn test_memory_block_thread_safety() {
        use std::thread;
        use std::sync::Arc;

        let block = Arc::new(MemoryBlock::new(1024 * 1024).unwrap());
        let mut handles = vec![];

        // 在多个线程中同时访问内存块
        for i in 0..4 {
            let block_clone = Arc::clone(&block);
            let handle = thread::spawn(move || {
                let offset = i * 1024;
                if offset < block_clone.size {
                    block_clone.safe_write(offset, (i * 10) as u8).unwrap();
                }
            });
            handles.push(handle);
        }

        // 等待所有线程完成
        for handle in handles {
            handle.join().unwrap();
        }
    }

    #[test]
    fn test_memory_cleanup_safety() {
        // 测试清理过程中的安全性
        let result = cleanup_memory();
        assert!(result.is_ok());

        let (before, after, freed_mb) = result.unwrap();
        assert!(before.total > 0);
        assert!(after.total > 0);
        assert!(freed_mb >= 0.0);

        // 验证内存信息的合理性
        assert!(before.used <= before.total);
        assert!(after.used <= after.total);
    }
}

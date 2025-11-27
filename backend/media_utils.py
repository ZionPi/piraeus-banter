import os
from pydub import AudioSegment

def merge_audio_files(file_list: list[str], output_path: str, gap_ms: int = 300):
    """
    将多个音频文件合并为一个，中间插入静音片段
    """
    print(f"[Media] Merging {len(file_list)} files...")
    
    # 1. 创建一个空的音频段
    combined = AudioSegment.empty()
    
    # 创建静音片段 (用于间隔)
    silence = AudioSegment.silent(duration=gap_ms)

    count = 0
    for file_path in file_list:
        if not os.path.exists(file_path):
            print(f"[Media] Warning: File not found, skipping: {file_path}")
            continue
            
        try:
            # 加载音频 (支持 mp3, wav 等)
            # pydub 会自动识别格式
            segment = AudioSegment.from_file(file_path)
            
            # 添加到总轨道
            combined += segment
            
            # 添加间隔 (除了最后一个)
            if file_path != file_list[-1]:
                combined += silence
            
            count += 1
        except Exception as e:
            print(f"[Media] Error loading {file_path}: {e}")

    # 2. 导出
    if count > 0:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        print(f"[Media] Exporting to {output_path}...")
        
        # 导出参数：mp3, 码率 192k
        combined.export(output_path, format="mp3", bitrate="192k")
        return True, count
    else:
        return False, 0
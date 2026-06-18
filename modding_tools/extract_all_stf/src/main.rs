use std::collections::HashSet;
use std::fs::File;
use std::path::Path;
use swg_tre::TreArchive;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let client_dir = Path::new("/mnt/j/swgemu/StarWarsGalaxies");

    let tre_files = vec![
        "bottom.tre",
        "data_music_00.tre",
        "data_sample_00.tre",
        "data_sample_01.tre",
        "data_sample_02.tre",
        "data_sample_03.tre",
        "data_sample_04.tre",
        "data_animation_00.tre",
        "data_skeletal_mesh_00.tre",
        "data_skeletal_mesh_01.tre",
        "data_texture_00.tre",
        "data_texture_01.tre",
        "data_texture_02.tre",
        "data_texture_03.tre",
        "data_texture_04.tre",
        "data_texture_05.tre",
        "data_texture_06.tre",
        "data_texture_07.tre",
        "data_static_mesh_00.tre",
        "data_static_mesh_01.tre",
        "data_other_00.tre",
        "patch_00.tre",
        "patch_01.tre",
        "patch_02.tre",
        "patch_03.tre",
        "patch_04.tre",
        "patch_05.tre",
        "patch_06.tre",
        "patch_07.tre",
        "patch_08.tre",
        "patch_09.tre",
        "patch_10.tre",
        "data_sku1_00.tre",
        "data_sku1_01.tre",
        "data_sku1_02.tre",
        "data_sku1_03.tre",
        "data_sku1_04.tre",
        "data_sku1_05.tre",
        "patch_11_00.tre",
        "patch_11_01.tre",
        "data_sku1_06.tre",
        "patch_11_02.tre",
        "data_sku1_07.tre",
        "patch_11_03.tre",
        "patch_12_00.tre",
        "patch_sku1_12_00.tre",
        "patch_13_00.tre",
        "patch_sku1_13_00.tre",
        "patch_14_00.tre",
        "patch_sku1_14_00.tre",
        "default_patch.tre",
    ];

    println!("Scanning TRE archives for STF file paths...");
    let mut found_languages = HashSet::new();
    let mut stf_paths = HashSet::new();

    for tre_name in tre_files {
        let tre_path = client_dir.join(tre_name);
        if !tre_path.exists() {
            continue;
        }

        let file = File::open(&tre_path)?;
        let archive = match TreArchive::new(file) {
            Ok(arc) => arc,
            Err(_) => continue,
        };

        for name in archive.file_names() {
            let lower = name.to_lowercase();
            if lower.ends_with(".stf") && lower.contains("string/") {
                stf_paths.insert(name.to_string());
                
                // Extract language directory: e.g. "string/en/ui_auc.stf" -> "en"
                let parts: Vec<&str> = name.split('/').collect();
                for i in 0..parts.len() {
                    if parts[i].eq_ignore_ascii_case("string") && i + 1 < parts.len() {
                        found_languages.insert(parts[i + 1].to_string().to_lowercase());
                    }
                }
            }
        }
    }

    println!("\n--- Unique languages found in string/ directories ---");
    for lang in &found_languages {
        println!("Language folder: string/{}/", lang);
    }
    
    println!("\nTotal unique STF file paths: {}", stf_paths.len());
    
    // Print a few sample paths from other languages if any
    println!("\n--- Sample STF Paths ---");
    let mut sample_count = 0;
    for path in &stf_paths {
        if !path.to_lowercase().contains("string/en/") {
            println!("Non-English path: {}", path);
            sample_count += 1;
            if sample_count >= 15 {
                break;
            }
        }
    }
    if sample_count == 0 {
        println!("No non-English STF paths found!");
    }

    Ok(())
}


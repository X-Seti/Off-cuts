/**
 * gta_model_converter.c - A tool to convert GTA III/VC/SA model files - X-Seti
 *
 * Supports conversion of:
 * - DFF (3D models) TXD (Textures) and COL (Collision data)
 *
 * Compile with: gcc -o gta_model_converter gta_model_converter.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <unistd.h>

// RenderWare section IDs
#define RW_STRUCT         0x0001
#define RW_STRING         0x0002
#define RW_EXTENSION      0x0003
#define RW_TEXTURE        0x0006
#define RW_MATERIAL       0x0007
#define RW_MATERIALLIST   0x0008
#define RW_FRAMELIST      0x000E
#define RW_GEOMETRY       0x000F
#define RW_CLUMP          0x0010
#define RW_ATOMIC         0x0014
#define RW_GEOMETRYLIST   0x001A
#define RW_BINMESHPLG     0x050E
#define RW_NIGHTVERTEXCOLOR 0x0120

// Library version IDs
#define LC_VERSION        0x0800FFFF  // GTA III RenderWare version
#define VC_VERSION        0x0C02FFFF  // Vice City RenderWare version
#define SA_VERSION        0x1803FFFF  // San Andreas RenderWare version

// Game identifiers
typedef enum {
    GAME_LC,
    GAME_VC,
    GAME_SA,
    GAME_UNKNOWN
} GameVersion;

// File type enum
typedef enum {
    FILE_DFF,
    FILE_TXD,
    FILE_COL,
    FILE_UNKNOWN
} FileType;

typedef struct {
    uint32_t type;
    uint32_t size;
    uint32_t version;
} SectionHeader;

// Global variables
bool g_verbose = false;

// Function to get game version string
const char* get_game_name(GameVersion game) {
    switch (game) {
        case GAME_LC:   return "GTA III";
        case GAME_VC:   return "GTA Vice City";
        case GAME_SA:   return "GTA San Andreas";
        default:        return "Unknown";
    }
}

// Function to get file type string
const char* get_file_type_name(FileType type) {
    switch (type) {
        case FILE_DFF: return "DFF (Model)";
        case FILE_TXD: return "TXD (Texture)";
        case FILE_COL: return "COL (Collision)";
        default:       return "Unknown";
    }
}

// Function to determine game version from RW version
GameVersion game_from_version(uint32_t version) {
    if (version == LC_VERSION) return GAME_LC;
    if (version == VC_VERSION) return GAME_VC;
    if (version == SA_VERSION) return GAME_SA;
    return GAME_UNKNOWN;
}

// Function to get RW version from game
uint32_t version_from_game(GameVersion game) {
    switch (game) {
        case GAME_LC:   return LC_VERSION;
        case GAME_VC:   return VC_VERSION;
        case GAME_SA:   return SA_VERSION;
        default:        return 0;
    }
}

// Function to read a section header
SectionHeader read_section_header(FILE *file) {
    SectionHeader header;
    fread(&header.type, sizeof(uint32_t), 1, file);
    fread(&header.size, sizeof(uint32_t), 1, file);
    fread(&header.version, sizeof(uint32_t), 1, file);
    return header;
}

// Function to write a section header
void write_section_header(FILE *file, SectionHeader header) {
    fwrite(&header.type, sizeof(uint32_t), 1, file);
    fwrite(&header.size, sizeof(uint32_t), 1, file);
    fwrite(&header.version, sizeof(uint32_t), 1, file);
}

// Function to determine file type based on content
FileType detect_file_type(const char *filename) {
    FILE *file = fopen(filename, "rb");
    if (!file) return FILE_UNKNOWN;

    SectionHeader header = read_section_header(file);
    fclose(file);

    if (header.type == RW_STRUCT) {
        // Need to look deeper to determine if DFF or TXD
        file = fopen(filename, "rb");
        fseek(file, 12, SEEK_SET); // Skip main header
        SectionHeader subheader = read_section_header(file);
        fclose(file);

        if (subheader.type == RW_CLUMP) {
            return FILE_DFF;
        } else if (subheader.type == RW_TEXTURE) {
            return FILE_TXD;
        }
    } else if (strstr(filename, ".col") || strstr(filename, ".COL")) {
        // Basic check for collision files
        return FILE_COL;
    }

    return FILE_UNKNOWN;
}

// Function to convert a DFF file
bool convert_dff(const char *input_filename, const char *output_filename, GameVersion target_game) {
    FILE *input = fopen(input_filename, "rb");
    if (!input) {
        fprintf(stderr, "Cannot open input file: %s\n", input_filename);
        return false;
    }

    // Read header to determine source version
    SectionHeader main_header = read_section_header(input);
    GameVersion source_game = game_from_version(main_header.version);

    if (source_game == GAME_UNKNOWN) {
        fprintf(stderr, "Unknown or unsupported RenderWare version in DFF: 0x%08X\n", main_header.version);
        fclose(input);
        return false;
    }

    if (g_verbose) {
        printf("Source game: %s (0x%08X)\n", get_game_name(source_game), main_header.version);
        printf("Target game: %s (0x%08X)\n", get_game_name(target_game), version_from_game(target_game));
    }

    // Create output file
    FILE *output = fopen(output_filename, "wb");
    if (!output) {
        fprintf(stderr, "Cannot open output file: %s\n", output_filename);
        fclose(input);
        return false;
    }

    // Update version to target game
    main_header.version = version_from_game(target_game);

    // Write updated header
    write_section_header(output, main_header);

    // Copy and convert the rest of the file
    fseek(input, 0, SEEK_END);
    long file_size = ftell(input);
    fseek(input, 12, SEEK_SET); // Skip the header we already read

    uint8_t *buffer = malloc(file_size - 12);
    if (!buffer) {
        fprintf(stderr, "Memory allocation failed\n");
        fclose(input);
        fclose(output);
        return false;
    }

    fread(buffer, 1, file_size - 12, input);

    // Update all version numbers in sections
    uint32_t source_version = version_from_game(source_game);
    uint32_t target_version = version_from_game(target_game);

    // Simple approach for now: scan and replace version numbers
    for (long i = 0; i < file_size - 12 - 8; i += 4) {
        uint32_t *value = (uint32_t *)(buffer + i);
        if (*value == source_version) {
            *value = target_version;
        }
    }

    // Handle specific modifications for SA -> VC/III and VC -> III conversions
    if (source_game == GAME_SA && (target_game == GAME_VC || target_game == GAME_LC)) {
        // Need to remove SA-specific sections like night vertex colors
        // This is a basic implementation - a full converter would need more detailed structure parsing
        uint32_t *data = (uint32_t *)buffer;
        long sections = (file_size - 12) / 4;

        for (long i = 0; i < sections - 2; i++) {
            if (data[i] == RW_NIGHTVERTEXCOLOR) {
                // Found SA-specific section, get its size
                uint32_t section_size = data[i+1];

                // Skip this section by moving everything after it
                memmove(&data[i], &data[i + 2 + section_size/4],
                        (sections - i - 2 - section_size/4) * 4);

                // Update the file size
                if (g_verbose) {
                    printf("Removed SA-specific section\n");
                }
            }
        }
    }

    fwrite(buffer, 1, file_size - 12, output);

    free(buffer);
    fclose(input);
    fclose(output);

    return true;
}

// Function to convert a TXD file
bool convert_txd(const char *input_filename, const char *output_filename, GameVersion target_game) {
    FILE *input = fopen(input_filename, "rb");
    if (!input) {
        fprintf(stderr, "Cannot open input file: %s\n", input_filename);
        return false;
    }

    // Read header to determine source version
    SectionHeader main_header = read_section_header(input);
    GameVersion source_game = game_from_version(main_header.version);

    if (source_game == GAME_UNKNOWN) {
        fprintf(stderr, "Unknown or unsupported RenderWare version in TXD: 0x%08X\n", main_header.version);
        fclose(input);
        return false;
    }

    if (g_verbose) {
        printf("Source game: %s (0x%08X)\n", get_game_name(source_game), main_header.version);
        printf("Target game: %s (0x%08X)\n", get_game_name(target_game), version_from_game(target_game));
    }

    // Create output file
    FILE *output = fopen(output_filename, "wb");
    if (!output) {
        fprintf(stderr, "Cannot open output file: %s\n", output_filename);
        fclose(input);
        return false;
    }

    // Update version to target game
    main_header.version = version_from_game(target_game);

    // Write updated header
    write_section_header(output, main_header);

    // Copy and convert the rest of the file
    fseek(input, 0, SEEK_END);
    long file_size = ftell(input);
    fseek(input, 12, SEEK_SET); // Skip the header we already read

    uint8_t *buffer = malloc(file_size - 12);
    if (!buffer) {
        fprintf(stderr, "Memory allocation failed\n");
        fclose(input);
        fclose(output);
        return false;
    }

    fread(buffer, 1, file_size - 12, input);

    // Update all version numbers in sections
    uint32_t source_version = version_from_game(source_game);
    uint32_t target_version = version_from_game(target_game);

    // Simple approach for now: scan and replace version numbers
    for (long i = 0; i < file_size - 12 - 8; i += 4) {
        uint32_t *value = (uint32_t *)(buffer + i);
        if (*value == source_version) {
            *value = target_version;
        }
    }

    // Handle texture compression differences between games
    // This is a placeholder - a full implementation would need to handle texture format conversion
    if ((source_game == GAME_SA && target_game != GAME_SA) ||
        (source_game != GAME_SA && target_game == GAME_SA)) {
        printf("Warning: Texture compression formats may differ between games. Manual texture editing may be required.\n");
    }

    fwrite(buffer, 1, file_size - 12, output);

    free(buffer);
    fclose(input);
    fclose(output);

    return true;
}

// Function to convert a COL file
bool convert_col(const char *input_filename, const char *output_filename, GameVersion target_game) {
    FILE *input = fopen(input_filename, "rb");
    if (!input) {
        fprintf(stderr, "Cannot open input file: %s\n", input_filename);
        return false;
    }

    // COL files dont have standard RenderWare headers
    // They have specific formats per game

    // Read first bytes to try to determine format
    char header[4];
    fread(header, 1, 4, input);

    // Reset file pointer
    fseek(input, 0, SEEK_SET);

    // Guess source game from header
    GameVersion source_game = GAME_UNKNOWN;
    if (memcmp(header, "COLL", 4) == 0) {
        source_game = GAME_LC; // GTA III & VC use similar formats
    } else if (memcmp(header, "COL", 3) == 0 && header[3] >= '2' && header[3] <= '3') {
        source_game = GAME_SA; // SA uses COL2 or COL3
    }

    if (source_game == GAME_UNKNOWN) {
        fprintf(stderr, "Unknown collision file format\n");
        fclose(input);
        return false;
    }

    if (g_verbose) {
        printf("Source game: %s\n", get_game_name(source_game));
        printf("Target game: %s\n", get_game_name(target_game));
    }

    // If source and target are compatible, just copy
    if ((source_game == GAME_LC || source_game == GAME_VC) &&
        (target_game == GAME_LC || target_game == GAME_VC)) {
        FILE *output = fopen(output_filename, "wb");
        if (!output) {
            fprintf(stderr, "Cannot open output file: %s\n", output_filename);
            fclose(input);
            return false;
        }

        // Get file size
        fseek(input, 0, SEEK_END);
        long file_size = ftell(input);
        fseek(input, 0, SEEK_SET);

        // Copy entire file
        uint8_t *buffer = malloc(file_size);
        if (!buffer) {
            fprintf(stderr, "Memory allocation failed\n");
            fclose(input);
            fclose(output);
            return false;
        }

        fread(buffer, 1, file_size, input);
        fwrite(buffer, 1, file_size, output);

        free(buffer);
        fclose(input);
        fclose(output);

        return true;
    } else {
        // Converting between SA and earlier games requires more complex parsing
        printf("Warning: Conversion between SA and earlier collision formats requires structural changes.\n");
        printf("Basic conversion applied but manual checking recommended.\n");

        FILE *output = fopen(output_filename, "wb");
        if (!output) {
            fprintf(stderr, "Cannot open output file: %s\n", output_filename);
            fclose(input);
            return false;
        }

        // Get file size
        fseek(input, 0, SEEK_END);
        long file_size = ftell(input);
        fseek(input, 0, SEEK_SET);

        uint8_t *buffer = malloc(file_size);
        if (!buffer) {
            fprintf(stderr, "Memory allocation failed\n");
            fclose(input);
            fclose(output);
            return false;
        }

        fread(buffer, 1, file_size, input);

        // Convert header if needed
        if (source_game == GAME_SA && (target_game == GAME_LC || target_game == GAME_VC)) {
            // Convert SA COL2/3 to GTA3/VC COLL
            memcpy(buffer, "COLL", 4);
        } else if ((source_game == GAME_LC || source_game == GAME_VC) && target_game == GAME_SA) {
            // Convert GTA3/VC COLL to SA COL2
            memcpy(buffer, "COL2", 4);
        }

        fwrite(buffer, 1, file_size, output);

        free(buffer);
        fclose(input);
        fclose(output);

        return true;
    }
}

// Main processing function
bool convert_file(const char *input_filename, const char *output_filename, GameVersion target_game) {
    FileType file_type = detect_file_type(input_filename);

    if (file_type == FILE_UNKNOWN) {
        fprintf(stderr, "Unknown file type: %s\n", input_filename);
        return false;
    }

    if (g_verbose) {
        printf("File type: %s\n", get_file_type_name(file_type));
    }

    switch (file_type) {
        case FILE_DFF:
            return convert_dff(input_filename, output_filename, target_game);
        case FILE_TXD:
            return convert_txd(input_filename, output_filename, target_game);
        case FILE_COL:
            return convert_col(input_filename, output_filename, target_game);
        default:
            return false;
    }
}

void print_usage(const char *program_name) {
    printf("GTA Model Converter (X-Seti) - Convert between GTA III, VC, & SA model files.\n\n");
    printf("Usage: %s [options] input_file output_file\n", program_name);
    printf("Options:\n");
    printf("  -g <game>   Target game: lc (GTA III), vc (Vice City), sa (San Andreas)\n");
    printf("  -v          Verbose output\n");
    printf("\nExamples:\n");
    printf("  %s -g sa car.dff car_sa.dff               # Convert to SA\n", program_name);
    printf("  %s -g vc -v building.dff building_vc.dff  # Convert to VC\n", program_name);
    printf("  %s -g lc -v building.dff building_lc.dff  # Convert to LC\n", program_name);
}

int main(int argc, char *argv[]) {
    char *input_file = NULL;
    char *output_file = NULL;
    GameVersion target_game = GAME_SA; // Default to SA
    int opt;

    // Parse command line options
    while ((opt = getopt(argc, argv, "g:v")) != -1) {
        switch (opt) {
            case 'g':
                if (strcmp(optarg, "lc") == 0) {
                    target_game = GAME_LC;
                } else if (strcmp(optarg, "vc") == 0) {
                    target_game = GAME_VC;
                } else if (strcmp(optarg, "sa") == 0) {
                    target_game = GAME_SA;
                } else {
                    fprintf(stderr, "Invalid game selection: %s\n", optarg);
                    print_usage(argv[0]);
                    return EXIT_FAILURE;
                }
                break;
            case 'v':
                g_verbose = true;
                break;
            default:
                print_usage(argv[0]);
                return EXIT_FAILURE;
        }
    }

    // Get input and output files
    if (optind < argc) {
        input_file = argv[optind++];
    }

    if (optind < argc) {
        output_file = argv[optind++];
    }

    if (input_file == NULL || output_file == NULL) {
        fprintf(stderr, "Missing required arguments\n");
        print_usage(argv[0]);
        return EXIT_FAILURE;
    }

    if (g_verbose) {
        printf("Converting %s to %s (Target: %s)\n",
               input_file, output_file, get_game_name(target_game));
    }

    if (convert_file(input_file, output_file, target_game)) {
        if (g_verbose) {
            printf("Conversion successful\n");
        }
        return EXIT_SUCCESS;
    } else {
        fprintf(stderr, "Conversion failed\n");
        return EXIT_FAILURE;
    }
}

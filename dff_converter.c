/**
 * dff_converter.c X-Seti - A tool to convert GTA VC DFF files to SA format.
 *
 * Compile with: gcc -o dff_converter dff_converter.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

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

// Library version IDs
#define VC_VERSION        0x0C02FFFF  // Vice City RenderWare version
#define SA_VERSION        0x1803FFFF  // San Andreas RenderWare version

typedef struct {
    uint32_t type;
    uint32_t size;
    uint32_t version;
} SectionHeader;

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

// Function to convert a single section
void convert_section(FILE *input, FILE *output, SectionHeader header) {
    // Buffer to hold section data
    uint8_t *buffer = malloc(header.size);
    if (!buffer) {
        fprintf(stderr, "Memory allocation failed for section of size %u\n", header.size);
        exit(EXIT_FAILURE);
    }

    // Read section data
    fread(buffer, 1, header.size, input);

    // Update version if this is a RenderWare structure header
    if (header.version == VC_VERSION) {
        header.version = SA_VERSION;
    }

    // Write updated header
    write_section_header(output, header);

    // Write section data
    fwrite(buffer, 1, header.size, output);

    free(buffer);
}

// Main function to handle conversion
bool convert_dff(const char *input_filename, const char *output_filename) {
    FILE *input = fopen(input_filename, "rb");
    if (!input) {
        fprintf(stderr, "Cannot open input file: %s\n", input_filename);
        return false;
    }

    FILE *output = fopen(output_filename, "wb");
    if (!output) {
        fprintf(stderr, "Cannot open output file: %s\n", output_filename);
        fclose(input);
        return false;
    }

    // Process the file header and structure
    SectionHeader main_header = read_section_header(input);
    if (main_header.type != RW_STRUCT ||
        (main_header.version != VC_VERSION && main_header.version != SA_VERSION)) {
        fprintf(stderr, "Invalid DFF file or unsupported version: %s\n", input_filename);
        fclose(input);
        fclose(output);
        return false;
    }

    // Update version to San Andreas
    main_header.version = SA_VERSION;
    write_section_header(output, main_header);

    // Copy and convert the rest of the file
    // For now, we're doing a simple version conversion, not full structure modification
    long start_pos = ftell(input);
    fseek(input, 0, SEEK_END);
    long file_size = ftell(input);
    fseek(input, start_pos, SEEK_SET);

    uint8_t *buffer = malloc(file_size - start_pos);
    if (!buffer) {
        fprintf(stderr, "Memory allocation failed\n");
        fclose(input);
        fclose(output);
        return false;
    }

    fread(buffer, 1, file_size - start_pos, input);

    // Simple conversion for now: just change version numbers embedded in the file
    // Note: This is a naive approach and would need refinement for proper conversion
    for (long i = 0; i < file_size - start_pos - 8; i += 4) {
        uint32_t *value = (uint32_t *)(buffer + i);
        if (*value == VC_VERSION) {
            *value = SA_VERSION;
        }
    }

    fwrite(buffer, 1, file_size - start_pos, output);

    free(buffer);
    fclose(input);
    fclose(output);

    return true;
}

void print_usage(const char *program_name) {
    printf("Usage: %s [-v] input.dff output.dff\n", program_name);
    printf("Options:\n");
    printf("  -v    Verbose output\n");
}

int main(int argc, char *argv[]) {
    bool verbose = false;
    char *input_file = NULL;
    char *output_file = NULL;

    // Parse command line arguments
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-v") == 0) {
            verbose = true;
        } else if (input_file == NULL) {
            input_file = argv[i];
        } else if (output_file == NULL) {
            output_file = argv[i];
        } else {
            fprintf(stderr, "Too many arguments\n");
            print_usage(argv[0]);
            return EXIT_FAILURE;
        }
    }

    if (input_file == NULL || output_file == NULL) {
        fprintf(stderr, "Missing required arguments\n");
        print_usage(argv[0]);
        return EXIT_FAILURE;
    }

    if (verbose) {
        printf("Converting %s to %s\n", input_file, output_file);
    }

    if (convert_dff(input_file, output_file)) {
        if (verbose) {
            printf("Conversion successful\n");
        }
        return EXIT_SUCCESS;
    } else {
        fprintf(stderr, "Conversion failed\n");
        return EXIT_FAILURE;
    }
}

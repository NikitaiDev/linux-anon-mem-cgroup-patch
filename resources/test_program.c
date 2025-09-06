#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    size_t size = 5 * 1024 * 1024; // Default
    
    if (argc > 1) {
        size = atoi(argv[1]);
    }
    
    printf("Allocating %zu bytes of anonymous memory...\n", size);
    printf("Process PID: %d\n", getpid());
    
    char *memory = malloc(size);
    if (memory) {
        memset(memory, 0, size);
        printf("Memory successfully allocated and filled.\n");
        printf("Holding memory for 5 seconds...\n");
        
        sleep(5);
        
        free(memory);
        printf("Memory freed.\n");
    } else {
        printf("Memory allocation failed!\n");
        return 1;
    }
    
    return 0;
}
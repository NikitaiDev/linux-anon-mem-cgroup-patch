#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>

int main(int argc, char *argv[]) {
    size_t size = 5 * 1024 * 1024;
    
    if (argc > 1) {
        size = atoi(argv[1]);
    }
    
    printf("Allocating %zu bytes via mmap (anonymous)...\n", size);
    printf("Process PID: %d\n", getpid());
    
    // Прямое выделение анонимной памяти через mmap
    char *memory = mmap(NULL, size, PROT_READ|PROT_WRITE, 
                       MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);
    
    if (memory == MAP_FAILED) {
        printf("mmap failed!\n");
        return 1;
    }
    
    // Гарантированно занимаем физическую память
    printf("Touching all pages to force physical allocation...\n");
    for (size_t i = 0; i < size; i += 4096) {
        memory[i] = 0;
    }
    
    printf("Memory successfully allocated and filled.\n");
    printf("Holding memory for 10 seconds...\n");
    
    sleep(10);
    
    munmap(memory, size);
    printf("Memory freed.\n");
    
    return 0;
}
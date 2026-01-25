#include <stdio.h>
#include <dlfcn.h>

int main(void) {
  const void *vk_handle = dlopen("libvulkan.so.1", RTLD_NOW);

  if (vk_handle) {
    printf("loaded libvulkan!\n");
  }

  const void* get_instance_proc_addr = dlsym(vk_handle, "vkGetInstanceProcAddr");

  if ((long unsigned)get_instance_proc_addr != 0) {
    printf("located vkGetInstanceProcAddr (0x%lx)\n", (long unsigned) get_instance_proc_addr);
  }
  return 0;
}

extern "C" void kernel_print(const char* text);

static bool equals(const char* left, const char* right) {
    while (*left && *left == *right) {
        ++left;
        ++right;
    }
    return *left == *right;
}

extern "C" void user_command(const char* command) {
    if (equals(command, "hello")) {
        kernel_print("Hello from your C++ command!\r\n");
        return;
    }
    
    if (equals(command, "Ashley")) {
        kernel_print("Fuh yeah i'm the best\r\n");
        return;
    }

    kernel_print("Unknown command. Type 'help' for the command list.\r\n");
}

__attribute__((visibility("default")))
int add(int a, int b);

int entry() {
    int result1 = add(2, 3);
    int result2 = add(5, 7);
    return result1 + result2; // Should return 17
}

int add(int a, int b) {
    return a + b;
}

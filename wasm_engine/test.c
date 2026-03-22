__attribute__((visibility("default")))
int add(int a, int b);

int entry() {
    int a = 0;
    while (a < 10) {
        a = add(a, 1);
    }
    if (a == 10) {
        return 0;
    } else {
        return 1;
    }
}

int add(int a, int b) {
    return a + b;
}

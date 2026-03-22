__attribute__((visibility("default")))
int add(int a, int b);

int entry() {
    int a = 0;
    while (a < 10) {
        a = add(a, 1);
    }
    if (a == 10) {
        return 10;
    } else {
        return 3;
    }
}

int add(int a, int b) {
    return a + b;
}

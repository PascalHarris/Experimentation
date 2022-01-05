#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

void randomize() {
	uint32_t seed=0;
	FILE *devrnd = fopen("/dev/random","r");
	fread(&seed, 4, 1, devrnd);
	fclose(devrnd);
	srand(seed);
}

int* reverse_array(int input_array[], size_t elements) {
	int* return_array = malloc(sizeof(input_array[0]) * elements);
	for (size_t i = elements; i > 0; i--) {
		return_array[i - 1] = input_array[elements - i];
	}
	return return_array;
}

int* shuffle_array(int *input_array, size_t elements) {
	int* return_array = malloc(sizeof(input_array[0]) * elements);
	randomize();
	memcpy(return_array, input_array, sizeof(input_array[0]) * elements);
	if (elements > 1) {
		for (size_t i = 0; i < elements - 1; i++)  {
			size_t j = i + rand() / (RAND_MAX / (elements - i) + 1);
			int t = return_array[j];
			return_array[j] = return_array[i];
			return_array[i] = t;
		}
	}
	return return_array;
}

int main(int argc, char *argv[]) {
	int array[] = {70, 71, 72, 73, 74, 75, 76, 77, 78, 79};
	int elements = sizeof(array)/sizeof(array[0]);

	int* reversed_array = reverse_array(array, elements);
	int* scrambled_array = shuffle_array(array, elements);
	
	int a, b;

	a=1; b=2;
	printf("%d %d\n", a, b);
	for (int i = 0; i < elements; i++) {
		printf("%c %c %c\n", array[i], scrambled_array[i], reversed_array[i]);
	}
	
	free(reversed_array);
	free(scrambled_array);
}
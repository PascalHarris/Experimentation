#include <stdio.h>
#include <string.h>
#include <stdlib.h>

void reverse(char* input_string, int length) {
	int i = length - 1, j = 0;
	while (i > j) {
		char swap = input_string[i];
		input_string[i--] = input_string[j];
		input_string[j++] = swap;
	}
}

void reversewords(char* input_string, int length) {
	int i = length - 1, j = length - 1;
	char* temp_string = (char*)calloc(length + 1, sizeof(char));
	while (i >= 0) {
		if (input_string[i] == ' ' || i == 0) {
			char* test_string = (char*)calloc(j - i + 1, sizeof(char));
			strncpy(test_string, input_string+(i+(i>0?1:0)), j - i -(i == 0 || j == length - 1 ? 0 : 1)); 
			sprintf(temp_string, "%s%s ", temp_string, test_string);
			j = i;
			free(test_string);
		}
		i--;
	}
	memcpy(input_string, temp_string, length );
	free(temp_string);
}


int main(int argc, char *argv[]) {
	char* sentence = "break a link in-life either through termination of child or through a customer";
	char *test = (char*) malloc(strlen(sentence)*sizeof(char));
	strcpy(test, sentence);
	printf("%s\n", test);
	reverse(test, strlen(test));
	printf("%s\n", test);
	reversewords(test, strlen(test));
	printf("%s\n", test);
	reversewords(test, strlen(test));
	printf("%s\n", test);
	reverse(test, strlen(test));
	printf("%s\n", test);
	free(test);
}
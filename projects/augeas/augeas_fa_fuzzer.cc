#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

// Augea includes
#include "augeas.h"
#include "config.h"
#include "fa.h"
#include "internal.h"


/*
 * FA fuzzer. 
 */
extern "C"
int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size){
	if(Size<3){
		return 0;
	}
	char *new_str = (char *)malloc(Size+1);
	if (new_str == NULL){
		return 0;
	}
	memcpy(new_str, Data, Size);
	new_str[Size] = '\0';
	int intSize = (int)Size;	
	char *s;


	size_t len;
	int r = fa_expand_nocase(new_str, intSize, &s, &len);
	
	struct fa *fa2 = NULL; 
	int r2 = fa_compile(new_str, intSize, &fa2);

	struct fa *fa1 = NULL;	
	fa_compile(&new_str[1], intSize, &fa1);
	struct fa *fa_min;
	fa_min = fa_minus(fa1, fa2);
	
	if (fa2 != NULL)
	{
		char* word = NULL;
		size_t word_len = 0;
		fa_example(fa2, &word, &word_len);
		
		if(word != NULL) 
			free(word);

		fa_json(stdout, fa2);
		fa_minimize(fa2);
		fa_dot(stdout, fa2);
	}

	struct fa *fa_b = fa_make_basic(intSize);
	
	// cleanup
	if (s != NULL) 		free(s);
	if (new_str != NULL) 	free(new_str);
	if (fa_b != NULL)	fa_free(fa_b);
	if (fa_min != NULL) 	fa_free(fa_min);
	if (fa1 != NULL)	fa_free(fa1);
	if (fa2 != NULL)	fa_free(fa2);
	return 0;
}

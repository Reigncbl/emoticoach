# Groq Models Translation Quality Benchmark Report

## WITH REAL HUMAN REFERENCE TRANSLATIONS

**Date:** 2025-10-12 21:53:33

**Dataset:** rhyliieee/tagalog-filipino-english-translation (HuggingFace)

**Important:** This benchmark uses REAL human-created reference translations, not LLM-generated references. This provides more accurate and reliable evaluation.

## Overview

This benchmark evaluates the translation quality of various Groq models for Tagalog/Filipino to English translation using standard NLG metrics:

- **BLEU (1-4)**: Measures n-gram overlap between translation and reference
- **ROUGE (1, 2, L)**: Measures recall-oriented overlap
- **METEOR**: Considers synonyms and stemming

## Summary Results

| Model | BLEU-4 | ROUGE-L | METEOR | Avg Time (ms) |
|-------|--------|---------|--------|---------------|
| meta-llama/llama-4-scout-17b-16e-instruct | 0.6543 | 0.8500 | 0.8142 | 1827.13 |
| moonshotai/kimi-k2-instruct-0905 | 0.5551 | 0.8147 | 0.7572 | 893.62 |
| openai/gpt-oss-120b | 0.5254 | 0.7748 | 0.7080 | 2058.71 |

## Detailed Metrics

| Model | BLEU-1 | BLEU-2 | BLEU-3 | BLEU-4 | ROUGE-1 | ROUGE-2 | ROUGE-L | METEOR |
|-------|--------|--------|--------|--------|---------|---------|---------|--------|
| meta-llama/llama-4-scout-17b-16e-instruct | 0.7987 | 0.7413 | 0.6965 | 0.6543 | 0.8591 | 0.7535 | 0.8500 | 0.8142 | 
| moonshotai/kimi-k2-instruct-0905 | 0.7447 | 0.6741 | 0.6136 | 0.5551 | 0.8290 | 0.6880 | 0.8147 | 0.7572 | 
| openai/gpt-oss-120b | 0.6983 | 0.6249 | 0.5729 | 0.5254 | 0.7894 | 0.6613 | 0.7748 | 0.7080 | 

## Best Models by Metric

- **BLEU-4**: meta-llama/llama-4-scout-17b-16e-instruct (0.6543)
- **ROUGE-L**: meta-llama/llama-4-scout-17b-16e-instruct (0.8500)
- **METEOR**: meta-llama/llama-4-scout-17b-16e-instruct (0.8142)
- **avg_time**: moonshotai/kimi-k2-instruct-0905 (893.62ms)

## Sample Translations

### moonshotai/kimi-k2-instruct-0905

**Sample 1**
- Tagalog: *Tukuyin ang uri ng function na y = x^2 + 3*
- Reference: *Identify the type of the function y = x^2 + 3*
- Translation: *Identify the type of function of y = x² + 3*
- BLEU-4: 0.3265, METEOR: 0.6257

**Sample 2**
- Tagalog: *Ibigay ang pinaka-malamang na resulta ng sumusunod na equation.*
- Reference: *Provide the most likely result of the following equation.*
- Translation: *Give the most likely result of the following equation.*
- BLEU-4: 0.8633, METEOR: 0.8880

**Sample 3**
- Tagalog: *Ang Iron Man, na kilala rin bilang Tony Stark, ay isang sikat na karakter mula sa Marvel Cinematic Universe.*
- Reference: *Iron Man, also known as Tony Stark, is a popular character from the Marvel Cinematic Universe.*
- Translation: *Iron Man, also known as Tony Stark, is a famous character from the Marvel Cinematic Universe.*
- BLEU-4: 0.8154, METEOR: 0.9364

### meta-llama/llama-4-scout-17b-16e-instruct

**Sample 1**
- Tagalog: *Tukuyin ang uri ng function na y = x^2 + 3*
- Reference: *Identify the type of the function y = x^2 + 3*
- Translation: *Identify the type of function y = x^2 + 3*
- BLEU-4: 0.7109, METEOR: 0.8881

**Sample 2**
- Tagalog: *Ibigay ang pinaka-malamang na resulta ng sumusunod na equation.*
- Reference: *Provide the most likely result of the following equation.*
- Translation: *Give the most likely result of the following equation.*
- BLEU-4: 0.8633, METEOR: 0.8880

**Sample 3**
- Tagalog: *Ang Iron Man, na kilala rin bilang Tony Stark, ay isang sikat na karakter mula sa Marvel Cinematic Universe.*
- Reference: *Iron Man, also known as Tony Stark, is a popular character from the Marvel Cinematic Universe.*
- Translation: *Iron Man, also known as Tony Stark, is a popular character from the Marvel Cinematic Universe.*
- BLEU-4: 1.0000, METEOR: 0.9999

### openai/gpt-oss-120b

**Sample 1**
- Tagalog: *Tukuyin ang uri ng function na y = x^2 + 3*
- Reference: *Identify the type of the function y = x^2 + 3*
- Translation: *Identify the type of function \(y = x^{2} + 3\).*
- BLEU-4: 0.2734, METEOR: 0.4400

**Sample 2**
- Tagalog: *Ibigay ang pinaka-malamang na resulta ng sumusunod na equation.*
- Reference: *Provide the most likely result of the following equation.*
- Translation: *Provide the most likely result of the following equation.*
- BLEU-4: 1.0000, METEOR: 0.9993

**Sample 3**
- Tagalog: *Ang Iron Man, na kilala rin bilang Tony Stark, ay isang sikat na karakter mula sa Marvel Cinematic Universe.*
- Reference: *Iron Man, also known as Tony Stark, is a popular character from the Marvel Cinematic Universe.*
- Translation: *Iron Man, also known as Tony Stark, is a famous character from the Marvel Cinematic Universe.*
- BLEU-4: 0.8154, METEOR: 0.9364


## Conclusion

The best performing model overall (by BLEU-4) is **meta-llama/llama-4-scout-17b-16e-instruct**.

These results are based on real human reference translations, providing reliable evaluation of translation quality.

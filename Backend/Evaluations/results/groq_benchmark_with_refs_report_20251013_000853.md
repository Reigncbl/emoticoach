# Groq Models Translation Quality Benchmark Report

## WITH REAL HUMAN REFERENCE TRANSLATIONS

**Date:** 2025-10-13 00:08:53

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
| meta-llama/llama-4-scout-17b-16e-instruct | 0.8469 | 0.9423 | 0.9244 | 461.27 |
| openai/gpt-oss-120b | 0.7050 | 0.9275 | 0.8096 | 555.98 |
| moonshotai/kimi-k2-instruct-0905 | 0.6654 | 0.8881 | 0.8283 | 606.89 |

## Detailed Metrics

| Model | BLEU-1 | BLEU-2 | BLEU-3 | BLEU-4 | ROUGE-1 | ROUGE-2 | ROUGE-L | METEOR |
|-------|--------|--------|--------|--------|---------|---------|---------|--------|
| meta-llama/llama-4-scout-17b-16e-instruct | 0.9270 | 0.8990 | 0.8739 | 0.8469 | 0.9433 | 0.8849 | 0.9423 | 0.9244 | 
| openai/gpt-oss-120b | 0.8497 | 0.7835 | 0.7431 | 0.7050 | 0.9275 | 0.8548 | 0.9275 | 0.8096 | 
| moonshotai/kimi-k2-instruct-0905 | 0.8672 | 0.7920 | 0.7226 | 0.6654 | 0.8890 | 0.7381 | 0.8881 | 0.8283 | 

## Best Models by Metric

- **BLEU-4**: meta-llama/llama-4-scout-17b-16e-instruct (0.8469)
- **ROUGE-L**: meta-llama/llama-4-scout-17b-16e-instruct (0.9423)
- **METEOR**: meta-llama/llama-4-scout-17b-16e-instruct (0.9244)
- **avg_time**: meta-llama/llama-4-scout-17b-16e-instruct (461.27ms)

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
- Translation: *Give the most likely result of the following equation.*
- BLEU-4: 0.8633, METEOR: 0.8880

**Sample 3**
- Tagalog: *Ang Iron Man, na kilala rin bilang Tony Stark, ay isang sikat na karakter mula sa Marvel Cinematic Universe.*
- Reference: *Iron Man, also known as Tony Stark, is a popular character from the Marvel Cinematic Universe.*
- Translation: *Iron Man, also known as Tony Stark, is a popular character from the Marvel Cinematic Universe.*
- BLEU-4: 1.0000, METEOR: 0.9999


## Conclusion

The best performing model overall (by BLEU-4) is **meta-llama/llama-4-scout-17b-16e-instruct**.

These results are based on real human reference translations, providing reliable evaluation of translation quality.

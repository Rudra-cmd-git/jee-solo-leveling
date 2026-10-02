import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const { submissionId, photoUrl } = await request.json();

    if (!submissionId || !photoUrl) {
      return NextResponse.json(
        { error: 'Submission ID and photo URL are required' },
        { status: 400 }
      );
    }

    // Call VisionSter API (no API key required)
    const response = await fetch('https://ahm7xmakki.com/imgchat', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        userPrompt: `Analyze this image to determine if it contains genuine JEE (Joint Entrance Examination) level study work in Physics, Chemistry, or Mathematics.

Look for:
- Handwritten solutions to problems, including equations, derivations, and calculations.
- Diagrams relevant to JEE topics: free-body diagrams, circuit diagrams, ray optics, molecular structures, coordinate geometry graphs, etc.
- Textbook pages with annotations, highlighting, or notes indicating active study.
- Practice problems from JEE-level resources (past papers, mock tests, advanced textbooks).

Reject if the image shows:
- Unrelated personal content (selfies, landscapes, etc.)
- Blank pages or pages with only printed text and no handwritten notes/highlighting.
- Screenshots of games, social media, videos, or non-educational content.
- Images that are purely decorative or lack any educational value.
- Content that is below JEE level (e.g., elementary school math) unless it's part of a larger JEE problem.

Respond with a JSON object containing exactly these fields:
- "verdict": either "approved" or "rejected"
- "confidence": a float between 0.0 and 1.0 indicating your confidence
- "reasoning": a brief string explaining your decision

Do not include any additional text or formatting outside the JSON.`,
        image: photoUrl
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('VisionSter API error:', errorText);
      return NextResponse.json(
        { error: 'VisionSter verification failed', details: errorText },
        { status: response.status || 500 }
      );
    }

    const responseText = await response.text();

    let result: {
      verdict?: string;
      confidence?: number;
      reasoning?: string;
    } = {};

    try {
      // Try to parse JSON from the response
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        result = JSON.parse(jsonMatch[0]);
      } else {
        // Fallback: check if response contains approval/rejection keywords
        const lowerText = responseText.toLowerCase();
        result = {
          verdict: lowerText.includes('approved') && !lowerText.includes('rejected') ? 'approved' : 'rejected',
          confidence: 0.7,
          reasoning: 'Parsed from VisionSter text response',
        };
      }
    } catch (parseError) {
      console.error('Failed to parse VisionSter response:', parseError);
      result = {
        verdict: 'rejected',
        confidence: 0.5,
        reasoning: 'Failed to parse VisionSter response',
      };
    }

    const verdict = result.verdict?.toLowerCase() === 'approved' ? 'approved' : 'rejected';
    const confidence = Math.max(0, Math.min(1, Number(result.confidence) || 0.5));
    const reasoning = String(result.reasoning || 'No reasoning provided');

    return NextResponse.json({
      submissionId,
      verdict,
      confidence,
      reasoning,
      verifiedAt: new Date().toISOString(),
    });
  } catch (error: unknown) {
    console.error('Verification error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json(
      { error: 'Internal verification error', details: errorMessage },
      { status: 500 }
    );
  }
}
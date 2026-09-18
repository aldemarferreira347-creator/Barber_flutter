export interface SubmitRatingInput {
  appointmentId: string;
  clientId: string;
  barberStars: number;
  shopStars: number;
}

export interface SubmitCommentInput {
  appointmentId: string;
  clientId: string;
  text: string;
  photoUrl: string | null;
}

export interface ReplyToCommentInput {
  commentId: string;
  barberId: string;
  replyText: string;
}

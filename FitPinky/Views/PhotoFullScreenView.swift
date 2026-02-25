import SwiftUI

struct PhotoEntry: Identifiable {
    let id: UUID
    let workout: Workout
    let memberName: String
    let date: Date
    let caption: String?

    init(workout: Workout, memberName: String) {
        self.id = workout.id
        self.workout = workout
        self.memberName = memberName
        self.date = workout.loggedAt
        self.caption = workout.caption
    }
}

extension Array where Element == Workout {
    func photoEntries(currentUserId: UUID, currentUserName: String, partnerName: String) -> [PhotoEntry] {
        compactMap { workout in
            guard workout.hasPhoto else { return nil }
            let name = workout.userId == currentUserId ? currentUserName : partnerName
            return PhotoEntry(workout: workout, memberName: name)
        }
    }
}

struct PhotoFullScreenView: View {
    let photos: [PhotoEntry]
    @State var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, entry in
                    photoPage(entry)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onChanged { value in
                    let isVertical = abs(value.translation.height) > abs(value.translation.width)
                    if isVertical && value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        dismiss()
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
                    }
                }
        )
        .background(Color.black)
        .statusBarHidden()
    }

    private func photoPage(_ entry: PhotoEntry) -> some View {
        VStack(spacing: 16) {
            Spacer()

            WorkoutPhotoView(workout: entry.workout, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)

            VStack(spacing: 6) {
                Text(entry.memberName)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(entry.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                if let caption = entry.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 4)
                }
            }

            Spacer()
        }
    }
}

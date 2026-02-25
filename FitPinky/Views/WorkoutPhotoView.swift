import SwiftUI

struct WorkoutPhotoView: View {
    let workout: Workout
    var contentMode: ContentMode = .fill

    @Environment(ActiveDataService.self) private var dataService
    @State private var image: UIImage?
    @State private var loaded = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if loaded {
                Color.surfaceBackground
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(Color.textSecondary)
                    }
            } else {
                Color.cardBackground
                    .overlay {
                        ProgressView()
                            .tint(Color.textSecondary)
                    }
            }
        }
        .task(id: workout.id) {
            if let photoData = workout.photoData {
                image = UIImage(data: photoData)
            } else {
                if let data = await dataService.loadPhoto(for: workout) {
                    image = UIImage(data: data)
                }
            }
            loaded = true
        }
    }
}
